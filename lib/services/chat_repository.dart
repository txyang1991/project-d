import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatRepository {
  ChatRepository._();
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

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
    return _db.collection('users').doc(uid)
      .collection('messages')
      .orderBy('ts')
      .snapshots();
  }

  static Future<void> addUserMessage(String text) async {
    if (text.trim().isEmpty) return;
    await _messagesCol().add({
      'role': 'user',
      'text': text.trim(),
      'ts': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> clearAll() async {
    final snap = await _messagesCol().get();
    final batch = _db.batch();
    for (final d in snap.docs) { batch.delete(d.reference); }
    await batch.commit();
  }
}
