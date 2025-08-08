import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Stream<User?> authStateChanges() => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;

  // --- Anonymous ---
  static Future<User?> signInAnonymously() async {
    final cred = await _auth.signInAnonymously();
    return cred.user;
  }

  // --- Email/Password sign-in ---
  static Future<User?> signInWithEmailPassword(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return cred.user;
  }

  // --- Email/Password registration ---
  static Future<User?> registerWithEmailPassword(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    return cred.user;
  }

  // --- Reset password ---
  static Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // --- Link anonymous -> email/password (upgrade guest) ---
  static Future<User?> linkAnonymousWithEmailPassword(String email, String password) async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw StateError('No anonymous user to upgrade.');
    }
    final credential = EmailAuthProvider.credential(email: email, password: password);
    final result = await user.linkWithCredential(credential);
    return result.user;
  }

  // --- Sign out ---
  static Future<void> signOut() async {
    await _auth.signOut();
  }
}
