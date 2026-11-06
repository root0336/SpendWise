import 'dart:async'; // Added for StreamSubscription
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'database_service.dart';
import 'transaction_model.dart';
import 'add_expense_screen.dart';
import 'transaction_history_screen.dart';
import 'view_analysis_screen.dart';
import 'wallet_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final DatabaseService _dbService = DatabaseService();

  // Logic for automatic limit notification
  StreamSubscription<bool>? _limitSubscription;
  bool _hasShownAlertThisSession = false;

  @override
  void initState() {
    super.initState();
    _setupLimitListener();
  }

  @override
  void dispose() {
    _limitSubscription?.cancel(); // Clean up the listener
    super.dispose();
  }

  void _setupLimitListener() {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    _limitSubscription = _dbService.streamIsOverLimit(userId).listen((
      isOverLimit,
    ) {
      if (!isOverLimit && mounted) {
        // Reset if they delete an expense and go under the limit
        setState(() {
          _hasShownAlertThisSession = false;
        });
      }
      // Note: Automatic popup trigger removed from here to prevent overlap
    });
  }

  // New Event-based check logic
  Future<void> _checkLimitManual() async {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    // Get the current state of the limit once
    final bool isOver = await _dbService.streamIsOverLimit(userId).first;

    if (isOver && !_hasShownAlertThisSession && mounted) {
      _showLimitAlert(context);
      setState(() {
        _hasShownAlertThisSession = true;
      });
    }
  }

  void _onItemTapped(int index) async {
    if (index == 0) return; // Already on Home

    // 1. Set the highlight so the user sees the click
    setState(() => _selectedIndex = index);

    // 2. Navigate and WAIT for the user to come back
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                index == 1
                    ? TransactionHistoryScreen(
                      userId: FirebaseAuth.instance.currentUser!.uid,
                    )
                    : index == 2
                    ? const WalletScreen()
                    : const ProfileScreen(),
      ),
    );

    // 3. THE FIX: Reset the highlight to 'Home' (0) once they press back
    if (mounted) setState(() => _selectedIndex = 0);
  }

  void _showLimitAlert(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder:
          (context) => Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).padding.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 60,
                ),
                const SizedBox(height: 16),
                Text(
                  "Budget Exceeded!",
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Your monthly spending has crossed the limit set in your wallet.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1AFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Understood",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  String _getRelativeTime(DateTime date) {
    final Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays == 1) return "Yesterday";
    return "${diff.inDays}d ago";
  }

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .snapshots(),
          builder: (context, userSnapshot) {
            return StreamBuilder<List<TransactionModel>>(
              stream: _dbService.getTransactions(userId),
              builder: (context, snapshot) {
                final transactions = snapshot.data ?? [];
                final userData =
                    userSnapshot.data?.data() as Map<String, dynamic>?;

                String fullCurrency = userData?['currency'] ?? "USD (\$)";
                String symbol = '\$';
                final match = RegExp(r'\((.*?)\)').firstMatch(fullCurrency);
                if (match != null) {
                  symbol = match.group(1)!;
                }

                final double income =
                    (userData?['monthlyIncome'] ?? 0).toDouble();
                double totalExpenses = transactions.fold(
                  0,
                  (sum, item) => sum + item.amount,
                );
                double balance = income - totalExpenses;
                String userName = userData?['name'] ?? "User";

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildHeader(userName, userId),
                      const SizedBox(height: 25),
                      _buildBalanceCard(balance, income, totalExpenses, symbol),
                      const SizedBox(height: 30),
                      _buildCategorySection(
                        transactions,
                        totalExpenses,
                        symbol,
                      ),
                      const SizedBox(height: 30),
                      _buildTransactionHeader(userId),
                      _buildTransactionList(transactions, symbol),
                      const SizedBox(height: 100),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // 1. Wait for the user to return from AddExpenseScreen
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
          );

          // 2. Trigger the event-based check once back on Home
          _checkLimitManual();
        },
        backgroundColor: const Color(0xFF1A1AFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader(String name, String userId) {
    String initials =
        name.isNotEmpty
            ? name
                .trim()
                .split(' ')
                .map((l) => l[0])
                .take(2)
                .join()
                .toUpperCase()
            : "U";

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF1A1AFF), width: 2),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1AFF),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  name,
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
        StreamBuilder<bool>(
          stream: _dbService.streamIsOverLimit(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return _buildNotificationIcon(false);
            }

            bool isOverLimit = snapshot.data ?? false;
            return _buildNotificationIcon(isOverLimit);
          },
        ),
      ],
    );
  }

  Widget _buildNotificationIcon(bool isOverLimit) {
    return GestureDetector(
      onTap: () {
        if (isOverLimit) {
          _showLimitAlert(context);
        }
      },
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    isOverLimit
                        ? Colors.red.withOpacity(0.5)
                        : Colors.grey.shade200,
                width: isOverLimit ? 2 : 1,
              ),
            ),
            child: Icon(
              isOverLimit
                  ? Icons.notifications_active
                  : Icons.notifications_none_rounded,
              color: isOverLimit ? Colors.red : Colors.black87,
            ),
          ),
          if (isOverLimit)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(
    double balance,
    double income,
    double expenses,
    String symbol,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1AFF), Color(0xFF4343FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Balance',
            style: GoogleFonts.manrope(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            '$symbol${balance.toStringAsFixed(2)}',
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatBox(
                Icons.arrow_downward,
                'INCOME',
                '$symbol${income.toInt()}',
              ),
              const SizedBox(width: 12),
              _buildStatBox(
                Icons.arrow_upward,
                'EXPENSES',
                '$symbol${expenses.toInt()}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    List<TransactionModel> transactions,
    double total,
    String symbol,
  ) {
    Map<String, double> catMap = {};
    for (var tx in transactions) {
      catMap[tx.category] = (catMap[tx.category] ?? 0) + tx.amount;
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Spending Categories',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            GestureDetector(
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AnalysisScreen(),
                    ),
                  ),
              child: Text(
                'View Analysis',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1AFF),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Row(
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: Stack(
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 0,
                        centerSpaceRadius: 40,
                        sections:
                            catMap.entries
                                .map(
                                  (e) => PieChartSectionData(
                                    color: _getCatColor(e.key),
                                    value: e.value,
                                    radius: 14,
                                    showTitle: false,
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'TOTAL',
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            '$symbol${(total / 1000).toStringAsFixed(1)}k',
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      catMap.entries.map((e) {
                        int percent =
                            total > 0 ? ((e.value / total) * 100).round() : 0;
                        return _buildLegendRow(
                          _getCatColor(e.key),
                          e.key,
                          percent,
                        );
                      }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionHeader(String userId) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Recent Transactions',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          GestureDetector(
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => TransactionHistoryScreen(userId: userId),
                  ),
                ),
            child: Text(
              'See All',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1AFF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(
    List<TransactionModel> transactions,
    String symbol,
  ) {
    final recentTxs =
        transactions.length > 5 ? transactions.sublist(0, 5) : transactions;
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recentTxs.length,
      itemBuilder: (context, index) {
        final tx = recentTxs[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getCatColor(tx.category).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _getCatIcon(tx.category),
                  color: _getCatColor(tx.category),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.title.isEmpty ? "No Note" : tx.title,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${tx.category} • ${_getRelativeTime(tx.date)}',
                      style: GoogleFonts.manrope(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '-$symbol${tx.amount.toStringAsFixed(2)}',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatBox(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendRow(Color color, String label, int percent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              '$label ($percent%)',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF1A1AFF),
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics_outlined),
          label: 'Insights',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet_outlined),
          label: 'Wallet',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
    );
  }

  Color _getCatColor(String category) {
    switch (category) {
      case 'Transport':
        return const Color(0xFF00C566);
      case 'Food':
        return const Color(0xFFFFBB00);
      case 'Shopping':
        return const Color(0xFFFF8C00);
      default:
        return const Color(0xFF1A1AFF);
    }
  }

  IconData _getCatIcon(String category) {
    switch (category) {
      case 'Shopping':
        return Icons.shopping_bag_outlined;
      case 'Food':
        return Icons.restaurant_outlined;
      case 'Transport':
        return Icons.directions_bus_filled_rounded;
      default:
        return Icons.category_outlined;
    }
  }
}
