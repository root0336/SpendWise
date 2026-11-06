import 'package:cloud_firestore/cloud_firestore.dart';
import 'transaction_model.dart';
import 'dart:async';
import 'package:rxdart/rxdart.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addTransaction(TransactionModel transaction) async {
    await _db
        .collection('transactions')
        .doc(transaction.id)
        .set(transaction.toMap());
  }

  Stream<List<TransactionModel>> getTransactions(String userId) {
    return _db
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => TransactionModel.fromMap(doc.data()))
                  .toList(),
        );
  }

  // --- STABILIZED OVER LIMIT LOGIC ---
  Stream<bool> streamIsOverLimit(String userId) {
    if (userId.isEmpty) return Stream.value(false);

    final now = DateTime.now();
    // We remove the strict 'startOfMonth' query constraint here because it
    // often causes flickering due to indexing delays. We filter in the MAP instead.

    Stream<DocumentSnapshot> userStream =
        _db.collection('users').doc(userId).snapshots();

    Stream<QuerySnapshot> transStream =
        _db
            .collection('transactions')
            .where('userId', isEqualTo: userId)
            .snapshots();

    return Rx.combineLatest2<
      DocumentSnapshot,
      QuerySnapshot,
      bool
    >(userStream, transStream, (userSnap, transSnap) {
      if (!userSnap.exists) return false;

      final userData = userSnap.data() as Map<String, dynamic>;

      // Use 'limit' or fallback to 0.0
      double limit =
          double.tryParse(userData['limit']?.toString() ?? '0') ?? 0.0;
      if (limit <= 0) return false;

      double totalSpent = 0.0;
      final currentMonth = now.month;
      final currentYear = now.year;

      for (var doc in transSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final dynamic dateData = data['date'];

        DateTime txDate;
        if (dateData is Timestamp) {
          txDate = dateData.toDate();
        } else if (dateData is String) {
          txDate = DateTime.parse(dateData);
        } else {
          continue;
        }

        // Strict month check to ensure we only sum current month
        if (txDate.month == currentMonth && txDate.year == currentYear) {
          totalSpent += (data['amount'] ?? 0).toDouble();
        }
      }

      // --- THE KEY FIX ---
      // If we have transactions but totalSpent is 0, it means the calculation
      // is likely in an 'async gap'. We check if we previously knew we were over limit.
      // For now, the direct comparison is much safer without the 'where' query flicker.
      return totalSpent > limit;
    }).distinct(); // .distinct() prevents the UI from rebuilding if the result is the same
  }
}
