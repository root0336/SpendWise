import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // This links the generated file
import 'onboardinglogo_screen.dart';

void main() async {
  // 1. Ensure Flutter framework is ready for async calls
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Firebase with the options from your generated file
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const SpendWiseApp());
}

class SpendWiseApp extends StatelessWidget {
  const SpendWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpendWise',
      debugShowCheckedModeBanner: false,
      // We will define our Royal Blue theme here later
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A1AFF)),
        useMaterial3: true,
      ),
      // For now, it shows a simple loading/check screen
      home: const OnboardingScreen(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // This is where we will eventually check if user is logged in
    return const Scaffold(
      body: Center(
        child: Text(
          'Firebase Connected! 🚀\nReady to build Login.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
