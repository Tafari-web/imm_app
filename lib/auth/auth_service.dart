import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Sign in existing user
  static Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Create new account
  static Future<UserCredential> signUp(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
        email: email, password: password);
  }

  /// Stream of auth changes
  static Stream<User?> get userStream => _auth.authStateChanges();

  /// Current user (nullable)
  static User? get currentUser => _auth.currentUser;

  /// Sign out
  static Future<void> signOut() => _auth.signOut();
}
