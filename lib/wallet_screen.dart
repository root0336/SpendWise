import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'database_service.dart';
import 'transaction_model.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final DatabaseService dbService = DatabaseService();

  String _getCurrencySymbol(String? currencyString) {
    if (currencyString == null) return '\$';
    final RegExp regExp = RegExp(r'\((.*?)\)');
    final match = regExp.firstMatch(currencyString);
    return match?.group(1) ?? '\$';
  }

  // UPDATED: Using .update instead of .set to prevent data reset flickers
  Future<void> _updateUserSetting(String field, double value) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        field: value,
      });
    } catch (e) {
      // Fallback if the document doesn't exist yet
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        field: value,
      }, SetOptions(merge: true));
    }
  }

  void _showEditDialog(
    String title,
    String field,
    double currentValue,
    String symbol,
  ) {
    TextEditingController controller = TextEditingController(
      text: currentValue.toString(),
    );
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              title,
              style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
            ),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: "$symbol ",
                hintText: "Enter amount",
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  _updateUserSetting(
                    field,
                    double.tryParse(controller.text) ?? 0,
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1AFF),
                ),
                child: const Text(
                  "Save",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Wallet',
          style: GoogleFonts.manrope(
            color: Colors.black,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .snapshots(),
        builder: (context, userSnapshot) {
          return StreamBuilder<List<TransactionModel>>(
            stream: dbService.getTransactions(userId),
            builder: (context, transSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final userData =
                  userSnapshot.data?.data() as Map<String, dynamic>?;
              final String symbol = _getCurrencySymbol(userData?['currency']);

              final double monthlyIncome =
                  (userData?['monthlyIncome'] ?? 0).toDouble();

              // Fetching from 'limit' field to match streamIsOverLimit logic
              final double expenseLimit = (userData?['limit'] ?? 0).toDouble();

              final transactions = transSnapshot.data ?? [];
              final double totalExpenses = transactions.fold(
                0,
                (sum, item) => sum + item.amount,
              );
              final double balance = monthlyIncome - totalExpenses;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBalanceCard(balance, monthlyIncome, symbol),
                    const SizedBox(height: 30),
                    _buildSectionHeader("Wallet Settings"),
                    _buildSettingTile(
                      icon: Icons.account_balance_wallet,
                      title: "Monthly Income",
                      subtitle: "$symbol${monthlyIncome.toStringAsFixed(2)}",
                      onTap:
                          () => _showEditDialog(
                            "Set Monthly Income",
                            "monthlyIncome",
                            monthlyIncome,
                            symbol,
                          ),
                    ),
                    _buildSettingTile(
                      icon: Icons.speed,
                      title: "Expense Limit",
                      subtitle:
                          expenseLimit > 0
                              ? "$symbol${expenseLimit.toStringAsFixed(2)}"
                              : "No limit set",
                      onTap:
                          () => _showEditDialog(
                            "Set Monthly Limit",
                            "limit",
                            expenseLimit,
                            symbol,
                          ),
                    ),
                    const SizedBox(height: 30),
                    _buildSectionHeader("Financial Health"),
                    _buildHealthCard(
                      expenseLimit > 0 ? expenseLimit : monthlyIncome,
                      totalExpenses,
                      expenseLimit > 0,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(double balance, double income, String symbol) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1AFF),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1AFF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Available Balance",
            style: GoogleFonts.manrope(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            "$symbol${balance.toStringAsFixed(2)}",
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Income: $symbol${income.toStringAsFixed(0)}",
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF1A1AFF)),
        ),
        title: Text(
          title,
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey),
        ),
        trailing: const Icon(Icons.edit, size: 18, color: Colors.grey),
      ),
    );
  }

  Widget _buildHealthCard(double target, double expenses, bool isLimitSet) {
    double percentUsed = target > 0 ? (expenses / target) : 0;
    String label = isLimitSet ? "Limit used" : "Income spent";
    double progressValue = percentUsed > 1.0 ? 1.0 : percentUsed;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
              ),
              Text(
                "${(percentUsed * 100).toStringAsFixed(0)}%",
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  color:
                      percentUsed > 0.9
                          ? Colors.red
                          : (percentUsed > 0.7 ? Colors.orange : Colors.green),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 10,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(
                percentUsed > 0.9
                    ? Colors.red
                    : (percentUsed > 0.7 ? Colors.orange : Colors.green),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            percentUsed >= 1.0
                ? "Critical: You have exceeded your $label!"
                : (percentUsed > 0.8
                    ? "Warning: Approaching your $label."
                    : "You are within your safe spending limit."),
            style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
