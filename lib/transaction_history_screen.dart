import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added for currency fetch
import 'database_service.dart';
import 'transaction_model.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final String userId;
  const TransactionHistoryScreen({super.key, required this.userId});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();

  String selectedCategory = 'All';
  String searchText = "";
  bool isSearching = false;

  // Helper function to extract symbol e.g., "USD ($)" -> "$"
  String _getCurrencySymbol(String? currencyString) {
    if (currencyString == null) return '\$';
    final RegExp regExp = RegExp(r'\((.*?)\)');
    final match = regExp.firstMatch(currencyString);
    return match?.group(1) ?? '\$';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: StreamBuilder<DocumentSnapshot>(
        // Fetch user profile for currency
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(widget.userId)
                .snapshots(),
        builder: (context, userSnapshot) {
          final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
          final String symbol = _getCurrencySymbol(userData?['currency']);

          return Column(
            children: [
              _buildCustomHeader(),
              const SizedBox(height: 10),
              _buildFilters(),
              Expanded(
                child: StreamBuilder<List<TransactionModel>>(
                  stream: _dbService.getTransactions(widget.userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting ||
                        userSnapshot.connectionState ==
                            ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text("No transactions found."),
                      );
                    }

                    final filteredList =
                        snapshot.data!.where((tx) {
                          final bool matchesCategory =
                              selectedCategory == 'All' ||
                              tx.category == selectedCategory;
                          final bool matchesSearch = tx.title
                              .toLowerCase()
                              .contains(searchText);
                          return matchesCategory && matchesSearch;
                        }).toList();

                    if (filteredList.isEmpty) {
                      return const Center(child: Text("No matches found."));
                    }

                    Map<String, List<TransactionModel>> groupedData =
                        _groupTransactions(filteredList);

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: groupedData.keys.length,
                      itemBuilder: (context, index) {
                        String dateKey = groupedData.keys.elementAt(index);
                        List<TransactionModel> items = groupedData[dateKey]!;

                        double dayTotal = items.fold(0.0, (sum, item) {
                          return item.category == 'Income'
                              ? sum + item.amount
                              : sum - item.amount;
                        });

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDateHeader(dateKey, dayTotal, symbol),
                            ...items.map(
                              (tx) => _buildTransactionTile(tx, symbol),
                            ),
                            const SizedBox(height: 10),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCustomHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          isSearching
              ? Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: "Search transactions...",
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    setState(() => searchText = value.toLowerCase());
                  },
                ),
              )
              : const Text(
                "Transactions",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
              ),
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                isSearching = !isSearching;
                if (!isSearching) {
                  _searchController.clear();
                  searchText = "";
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _filterDropdown(selectedCategory, [
            "All",
            "Food",
            "Transport",
            "Shopping",
            "Income",
          ], (val) => setState(() => selectedCategory = val)),
        ],
      ),
    );
  }

  Widget _filterDropdown(
    String label,
    List<String> options,
    Function(String) onSelect,
  ) {
    return PopupMenuButton<String>(
      onSelected: onSelect,
      itemBuilder:
          (context) =>
              options
                  .map((opt) => PopupMenuItem(value: opt, child: Text(opt)))
                  .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(String date, double total, String symbol) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            date.toUpperCase(),
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
          Text(
            "${total < 0 ? '-' : '+'}$symbol${total.abs().toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: total < 0 ? Colors.black : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(TransactionModel tx, String symbol) {
    IconData icon;
    Color color;
    bool isIncome = tx.category == 'Income';

    switch (tx.category) {
      case 'Food':
        icon = Icons.restaurant_rounded;
        color = const Color(0xFFFFBB00);
        break;
      case 'Transport':
        icon = Icons.directions_bus_rounded;
        color = const Color(0xFF00C566);
        break;
      case 'Income':
        icon = Icons.account_balance_wallet_rounded;
        color = Colors.green;
        break;
      default:
        icon = Icons.shopping_bag_rounded;
        color = const Color(0xFFFF8C00);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Text(
                  DateFormat('hh:mm a').format(tx.date),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            "${isIncome ? '+' : '-'}$symbol${tx.amount.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: isIncome ? Colors.green : Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<TransactionModel>> _groupTransactions(
    List<TransactionModel> transactions,
  ) {
    Map<String, List<TransactionModel>> grouped = {};
    for (var tx in transactions) {
      String dateKey;
      DateTime now = DateTime.now();
      if (tx.date.day == now.day &&
          tx.date.month == now.month &&
          tx.date.year == now.year) {
        dateKey = "Today";
      } else if (tx.date.day == now.day - 1 &&
          tx.date.month == now.month &&
          tx.date.year == now.year) {
        dateKey = "Yesterday";
      } else {
        dateKey = DateFormat('MMM dd, yyyy').format(tx.date);
      }
      if (grouped[dateKey] == null) grouped[dateKey] = [];
      grouped[dateKey]!.add(tx);
    }
    return grouped;
  }
}
