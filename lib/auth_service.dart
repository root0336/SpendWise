import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? get currentUser => _auth.currentUser;

  // 1. Sign Up logic
  Future<User?> signUp(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print("Sign Up Error: ${e.toString()}");
      return null;
    }
  }

  // 2. Login logic
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print("Login Error: ${e.toString()}");
      return null;
    }
  }

  // 3. Logout
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Add this inside your AuthService class
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      print("Reset Error: ${e.toString()}");
      throw e; // Pass error to UI to show a SnackBar
    }
  }
}
