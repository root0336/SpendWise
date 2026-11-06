import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'transaction_model.dart';
import 'database_service.dart';
import 'auth_service.dart';
import 'package:image_picker/image_picker.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();

  String _selectedCategory = 'Food';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _selectedImageName;

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImageName = image.name;
      });
    }
  }

  Future<void> _saveExpense() async {
    final amountText = _amountController.text.trim();
    final noteText = _titleController.text.trim();

    if (amountText.isEmpty || double.tryParse(amountText) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    final newTransaction = TransactionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: noteText.isEmpty ? "No Note" : noteText,
      amount: double.parse(amountText),
      category: _selectedCategory,
      date: _selectedDate,
      userId: currentUser.uid,
    );

    try {
      await _dbService.addTransaction(newTransaction);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;
    final formattedDate =
        "${DateFormat('EEEE').format(_selectedDate)}, ${DateFormat('MMM d').format(_selectedDate)}";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add New Expense',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ),
      // Added StreamBuilder to fetch user currency settings
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser?.uid)
                .snapshots(),
        builder: (context, snapshot) {
          // --- SYMBOL EXTRACTION ---
          String symbol = '\$'; // Default fallback
          if (snapshot.hasData && snapshot.data!.exists) {
            final userData = snapshot.data!.data() as Map<String, dynamic>;
            String fullCurrency = userData['currency'] ?? "USD (\$)";
            final match = RegExp(r'\((.*?)\)').firstMatch(fullCurrency);
            if (match != null) {
              symbol = match.group(1)!;
            }
          }

          return SafeArea(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 30),
                      Center(
                        child: Text(
                          'AMOUNT',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: IntrinsicWidth(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              // Replaced hardcoded Icon with dynamic Text symbol
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text(
                                  symbol,
                                  style: GoogleFonts.manrope(
                                    fontSize:
                                        48, // Adjusted size to match font weight
                                    color: const Color(0xFF1A1AFF),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 0,
                                minHeight: 0,
                              ),
                              border: InputBorder.none,
                              hintText: '0.00',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                      Text(
                        'Category',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildCategoryChip('Food', Icons.restaurant_outlined),
                          _buildCategoryChip(
                            'Transport',
                            Icons.directions_bus_filled_rounded,
                          ),
                          _buildCategoryChip(
                            'Shopping',
                            Icons.shopping_bag_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Date',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => _selectDate(context),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                formattedDate,
                                style: GoogleFonts.manrope(fontSize: 16),
                              ),
                              const Icon(Icons.keyboard_arrow_down_rounded),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Note (Optional)',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _titleController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'What was this for?',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8E8FF).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.receipt_long_rounded,
                              color: Color(0xFF1A1AFF),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Attach Receipt',
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    _selectedImageName ?? 'JPEG, PNG or PDF',
                                    style: GoogleFonts.manrope(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: _pickImage,
                              child: const Text(
                                'Upload',
                                style: TextStyle(
                                  color: Color(0xFF1A1AFF),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 24,
                  left: 24,
                  right: 24,
                  child: SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveExpense,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1AFF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child:
                          _isLoading
                              ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                              : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Save Expense',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryChip(String label, IconData icon) {
    bool isSelected = _selectedCategory == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = label),
      child: Chip(
        label: Text(
          label,
          style: TextStyle(color: isSelected ? Colors.white : Colors.black),
        ),
        avatar: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.black,
          size: 18,
        ),
        backgroundColor: isSelected ? const Color(0xFF1A1AFF) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
