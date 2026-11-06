import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final String userId;

  TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    required this.userId,
  });

  // Convert a Transaction object into a Map to store in Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'date': Timestamp.fromDate(date), // Firebase uses Timestamps
      'userId': userId,
    };
  }

  // Create a Transaction object from a Firebase Document
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      category: map['category'] ?? 'General',
      date: (map['date'] as Timestamp).toDate(),
      userId: map['userId'] ?? '',
    );
  }
}
