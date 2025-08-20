import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ChatRepository {
  ChatRepository._();
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // TODO: replace with your deployed function URL
  // static const String _fnUrl = 'https://us-central1-project-d-start-of-everything.cloudfunctions.net/echoChat'; // for firebase function
  static const String _fnUrl = 'https://echochat-cr-907834599183.us-central1.run.app/echoChat'; // e.g. https://us-central1-.../echoChat

  static String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in.');
    return uid;
  }

  // Path: /users/{uid}/messages/{messageId} 
  static CollectionReference<Map<String, dynamic>> _messagesCol() {
    final uid = _requireUid();
    return _db.collection('users').doc(uid).collection('messages');
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> streamMessages() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return _db
        .collection('users').doc(uid)
        .collection('messages')
        .orderBy('ts')
        .snapshots();
  }

  /// API stays the same: callers keep using addUserMessage(String).
  /// Implementation now calls the HTTPS Function, which writes BOTH:
  /// - the user message
  /// - the assistant reply (same Firestore shape as before)
  static Future<void> addUserMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) throw StateError('Not signed in.');
    final idToken = await user.getIdToken();

    final resp = await http.post(
      Uri.parse(_fnUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'text': trimmed}),
    );

    if (resp.statusCode != 200) {
      throw StateError('Backend error: ${resp.statusCode} ${resp.body}');
    }

    // We ignore the returned reply to keep API/behavior unchanged.
    // UI will update from streamMessages() as Firestore updates land.
  }

  static Future<void> clearAll() async {
    final snap = await _messagesCol().get();
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }
}
