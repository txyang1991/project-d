import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Stream<User?> authStateChanges() => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;

  // If your Windows/Desktop OAuth client ID is needed, put it here:
  // static const String _windowsClientId = 'YOUR_WINDOWS_OAUTH_CLIENT_ID.apps.googleusercontent.com';

  static GoogleSignIn _google() {
    // On desktop you may need to pass clientId. Uncomment if required:
    // if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    //   return GoogleSignIn(clientId: _windowsClientId);
    // }
    return GoogleSignIn();
  }

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

  // --- Google Sign-In (Windows/Desktop + Web + mobile) ---
  static Future<User?> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      final cred = await _auth.signInWithPopup(provider);
      return cred.user;
    }

    // Desktop / Mobile flow via google_sign_in
    final googleUser = await _google().signIn();
    if (googleUser == null) {
      throw Exception('Sign-in canceled.');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCred = await _auth.signInWithCredential(credential);
    return userCred.user;
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

  // --- Link anonymous -> Google (upgrade guest) ---
  static Future<User?> linkAnonymousWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw StateError('No anonymous user to upgrade.');
    }

    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      final linked = await user.linkWithPopup(provider);
      return linked.user;
    }

    final googleUser = await _google().signIn();
    if (googleUser == null) {
      throw Exception('Google linking canceled.');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final linked = await user.linkWithCredential(credential);
    return linked.user;
  }

  // --- Sign out ---
  static Future<void> signOut() async {
    // Sign out from Firebase
    await _auth.signOut();
    // Also disconnect Google if it was used, to avoid auto-pick account next time
    try {
      await _google().disconnect();
    } catch (_) {
      // ignore – disconnect may throw if not signed in via Google
    }
  }
}
