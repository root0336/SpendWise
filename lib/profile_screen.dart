import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- 1. Personal Info Dialog (Logic preserved) ---
  void _showPersonalInfoDialog(String currentName, String currentDob) {
    TextEditingController nameController = TextEditingController(
      text: currentName,
    );
    TextEditingController dobController = TextEditingController(
      text: currentDob,
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              "Edit Personal Info",
              style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Full Name",
                    hintText: "Enter your name",
                  ),
                ),
                TextField(
                  controller: dobController,
                  decoration: const InputDecoration(
                    labelText: "Date of Birth",
                    hintText: "DD/MM/YYYY",
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1AFF),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  String newName = nameController.text;
                  String newDob = dobController.text;
                  Navigator.pop(context);

                  _firestore
                      .collection('users')
                      .doc(user!.uid)
                      .update({'name': newName, 'dob': newDob})
                      .then((_) => user!.updateDisplayName(newName))
                      .catchError((e) => debugPrint("Update failed: $e"));
                },
                child: const Text("Save"),
              ),
            ],
          ),
    );
  }

  // --- 2. Currency Picker (Fixed for Navigation Bar overlapping) ---
  void _showCurrencyPicker(String currentCurrency) {
    List<String> currencies = [
      "USD (\$)",
      "EUR (€)",
      "GBP (£)",
      "PKR (Rs)",
      "INR (₹)",
    ];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows sheet to size correctly
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder:
          (context) => SafeArea(
            child: Padding(
              // Adds bottom padding to prevent system nav bar overlap
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
                children:
                    currencies
                        .map(
                          (c) => ListTile(
                            title: Text(
                              c,
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing:
                                currentCurrency == c
                                    ? const Icon(
                                      Icons.check,
                                      color: Color(0xFF1A1AFF),
                                    )
                                    : null,
                            onTap: () {
                              Navigator.pop(context);
                              _firestore
                                  .collection('users')
                                  .doc(user!.uid)
                                  .update({'currency': c});
                            },
                          ),
                        )
                        .toList(),
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null)
      return const Scaffold(body: Center(child: Text("No User Logged In")));

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
          'Profile',
          style: GoogleFonts.manrope(
            color: Colors.black,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(user!.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var userData = snapshot.data?.data() as Map<String, dynamic>?;
          String name = userData?['name'] ?? "User";
          String currency = userData?['currency'] ?? "USD (\$)";
          String dob = userData?['dob'] ?? "Not Set";

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildProfileHeader(name),
                const SizedBox(height: 40),
                _buildSectionLabel("ACCOUNT SETTINGS"),
                _buildSettingsCard([
                  _buildSettingTile(
                    Icons.person_outline,
                    "Personal Information",
                    subtitle: "DOB: $dob",
                    onTap: () => _showPersonalInfoDialog(name, dob),
                  ),
                  _buildSettingTile(
                    Icons.account_balance_wallet_outlined,
                    "Primary Currency",
                    trailingText: currency,
                    onTap: () => _showCurrencyPicker(currency),
                  ),
                  _buildSettingTile(
                    Icons.shield_outlined,
                    "Security & Privacy",
                    onTap: () => _showPrivacyPolicy(),
                  ),
                ]),
                const SizedBox(height: 40),
                _buildSignOutButton(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(String name) {
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

    return Column(
      children: [
        Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF1A1AFF), width: 4),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 110,
            height: 110,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: GoogleFonts.manrope(
                fontSize: 38,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1AFF),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          name,
          style: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        Text(
          user?.email ?? "",
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingTile(
    IconData icon,
    String title, {
    String? subtitle,
    String? trailingText,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF1A1AFF), size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      subtitle:
          subtitle != null
              ? Text(subtitle, style: GoogleFonts.manrope(fontSize: 12))
              : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText,
              style: GoogleFonts.manrope(
                color: const Color(0xFF1A1AFF),
                fontWeight: FontWeight.bold,
              ),
            ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Security & Privacy"),
            content: const Text(
              "All rights are reserved. Your data is encrypted and stored securely in Firebase.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 5, bottom: 10),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          await FirebaseAuth.instance.signOut();
          if (mounted)
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFEEEE),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          "Sign Out",
          style: GoogleFonts.manrope(
            color: Colors.red,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
