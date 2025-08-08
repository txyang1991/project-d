import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _google = GoogleSignIn(scopes: ['email']);

  static Stream<User?> authStateChanges() => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;

  static Future<User?> signInAnonymously() async {
    final cred = await _auth.signInAnonymously();
    return cred.user;
  }

  static Future<User?> signInWithGoogle() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      throw UnsupportedError('Google sign-in not supported on desktop.');
    }
    final googleUser = await _google.signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );
    final userCred = await _auth.signInWithCredential(credential);
    return userCred.user;
  }

  static Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _google.signOut();
    } catch (_) {}
  }
}
