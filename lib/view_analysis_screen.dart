import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added for currency fetch
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'database_service.dart';
import 'transaction_model.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  int _activeToggle = 0; // 0 for Last 7 Days, 1 for This Month

  // Helper function to extract symbol e.g., "USD ($)" -> "$"
  String _getCurrencySymbol(String? currencyString) {
    if (currencyString == null) return '\$';
    final RegExp regExp = RegExp(r'\((.*?)\)');
    final match = regExp.firstMatch(currencyString);
    return match?.group(1) ?? '\$';
  }

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final DatabaseService dbService = DatabaseService();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Analysis',
          style: GoogleFonts.manrope(
            color: Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          // Fetch user profile for currency
          stream:
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .snapshots(),
          builder: (context, userSnapshot) {
            final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
            final String symbol = _getCurrencySymbol(userData?['currency']);

            return StreamBuilder<List<TransactionModel>>(
              stream: dbService.getTransactions(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting ||
                    userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allTransactions = snapshot.data ?? [];
                if (allTransactions.isEmpty) {
                  return const Center(
                    child: Text("No transactions to analyze"),
                  );
                }

                List<TransactionModel> filteredTransactions = _filterData(
                  allTransactions,
                );

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      _buildToggleButton(),
                      const SizedBox(height: 25),
                      _buildSpendingTrend(filteredTransactions),
                      const SizedBox(height: 30),
                      _buildCategoryBreakdown(filteredTransactions, symbol),
                      const SizedBox(height: 30),
                      _buildTopExpense(filteredTransactions, symbol),
                      const SizedBox(height: 30),
                      _buildExportButton(filteredTransactions, symbol),
                      const SizedBox(height: 60),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // --- PDF EXPORT BUTTON ---
  Widget _buildExportButton(
    List<TransactionModel> transactions,
    String symbol,
  ) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _generatePdf(transactions, symbol),
        icon: const Icon(
          Icons.picture_as_pdf,
          size: 18,
          color: Color(0xFF1A1AFF),
        ),
        label: Text(
          "Export as PDF",
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1AFF),
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          side: const BorderSide(color: Color(0xFF1A1AFF), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // --- PDF GENERATION LOGIC ---
  Future<void> _generatePdf(
    List<TransactionModel> transactions,
    String symbol,
  ) async {
    final pdf = pw.Document();
    final String reportType = _activeToggle == 0 ? "Last 7 Days" : "This Month";

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build:
            (pw.Context context) => [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "Spending Report ($reportType)",
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(DateFormat('MMM dd, yyyy').format(DateTime.now())),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF1A1AFF),
                ),
                context: context,
                data: <List<String>>[
                  <String>['Date', 'Time', 'Category', 'Description', 'Amount'],
                  ...transactions.map(
                    (tx) => [
                      DateFormat('yyyy-MM-dd').format(tx.date),
                      DateFormat('hh:mm a').format(tx.date),
                      tx.category,
                      tx.title.isEmpty ? 'No Note' : tx.title,
                      '$symbol${tx.amount.toStringAsFixed(2)}', // PDF Symbol Update
                    ],
                  ),
                ],
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 20),
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    "Total: $symbol${transactions.fold(0.0, (sum, item) => sum + item.amount).toStringAsFixed(2)}", // PDF Symbol Update
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // --- TOGGLE BUTTON ---
  Widget _buildToggleButton() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _buildToggleItem(0, "Last 7 Days"),
          _buildToggleItem(1, "This Month"),
        ],
      ),
    );
  }

  Widget _buildToggleItem(int index, String label) {
    bool isActive = _activeToggle == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeToggle = index),
        child: Container(
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF1A1AFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: isActive ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  // --- FILTER LOGIC ---
  List<TransactionModel> _filterData(List<TransactionModel> txs) {
    final now = DateTime.now();
    if (_activeToggle == 0) {
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      return txs.where((tx) => tx.date.isAfter(sevenDaysAgo)).toList();
    } else {
      return txs
          .where((tx) => tx.date.month == now.month && tx.date.year == now.year)
          .toList();
    }
  }

  // --- LINE CHART: SPENDING TREND ---
  Widget _buildSpendingTrend(List<TransactionModel> transactions) {
    List<FlSpot> spots = [];
    String subtitle = _activeToggle == 0 ? "Daily Spending" : "Weekly Spending";

    if (_activeToggle == 0) {
      Map<String, double> dayTotals = {};
      for (var tx in transactions) {
        String dateKey = DateFormat('MM/dd').format(tx.date);
        dayTotals[dateKey] = (dayTotals[dateKey] ?? 0) + tx.amount;
      }
      for (int i = 0; i < 7; i++) {
        String key = DateFormat(
          'MM/dd',
        ).format(DateTime.now().subtract(Duration(days: 6 - i)));
        spots.add(FlSpot(i.toDouble(), dayTotals[key] ?? 0));
      }
    } else {
      Map<int, double> weekTotals = {1: 0, 2: 0, 3: 0, 4: 0};
      for (var tx in transactions) {
        int week = ((tx.date.day - 1) / 7).floor() + 1;
        if (week > 4) week = 4;
        weekTotals[week] = (weekTotals[week] ?? 0) + tx.amount;
      }
      weekTotals.forEach((week, total) {
        spots.add(FlSpot(week.toDouble(), total));
      });
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1AFF),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: GoogleFonts.manrope(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            _activeToggle == 0 ? 'Last 7 Days' : 'Monthly Overview',
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 30),
          AspectRatio(
            aspectRatio: 1.7,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.white,
                    barWidth: 4,
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- PIE CHART: CATEGORY BREAKDOWN ---
  Widget _buildCategoryBreakdown(
    List<TransactionModel> transactions,
    String symbol,
  ) {
    Map<String, double> catMap = {};
    for (var tx in transactions) {
      catMap[tx.category] = (catMap[tx.category] ?? 0) + tx.amount;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spending Breakdown',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          if (transactions.isEmpty)
            const Text("No data for this period")
          else
            Row(
              children: [
                SizedBox(
                  height: 100,
                  width: 100,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 0,
                      centerSpaceRadius: 30,
                      sections:
                          catMap.entries
                              .map(
                                (e) => PieChartSectionData(
                                  color: _getCatColor(e.key),
                                  value: e.value,
                                  radius: 12,
                                  showTitle: false,
                                ),
                              )
                              .toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children:
                        catMap.entries
                            .map(
                              (e) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 4,
                                          backgroundColor: _getCatColor(e.key),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          e.key,
                                          style: GoogleFonts.manrope(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '$symbol${e.value.toStringAsFixed(0)}', // UI Symbol Update
                                      style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // --- TOP EXPENSE CARD ---
  Widget _buildTopExpense(List<TransactionModel> transactions, String symbol) {
    if (transactions.isEmpty) return const SizedBox.shrink();

    final topTx = [...transactions]
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final highest = topTx.first;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.trending_up,
              color: Colors.redAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Biggest Expense",
                  style: GoogleFonts.manrope(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  highest.title.isEmpty ? "No Note" : highest.title,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '-$symbol${highest.amount.toStringAsFixed(2)}', // UI Symbol Update
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
        ],
      ),
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
}
