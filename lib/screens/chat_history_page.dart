// lib/screens/chat_history_page.dart
// Displays the single chat history for the signed-in user

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/message_model.dart';
import '../widgets/message_bubble.dart';
import '../services/chat_repository.dart';

class ChatHistoryPage extends StatelessWidget {
  const ChatHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Sign in to see your history.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ChatRepository.streamMessages(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No history yet'));

        final messages = docs.map((d) => Message.fromFirestore(d.data())).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (_, i) => MessageBubble(message: messages[i]),
        );
      },
    );
  }
}
