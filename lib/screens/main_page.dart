// lib/screens/main_page.dart
// Main chat page: persists messages per-user in Firestore

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/message_model.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';
import '../services/chat_repository.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final TextEditingController _controller = TextEditingController();

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _onSend() async {
    try {
      await ChatRepository.addUserMessage(_controller.text);
      _controller.clear();
    } catch (e) {
      _toast('$e');
    }
  }

  Future<void> _clearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear chat history?'),
        content: const Text('This deletes all your messages.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ChatRepository.clearAll();
        _toast('Chat history cleared');
      } catch (e) {
        _toast('Please sign in: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Sign in to start chatting.'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ChatRepository.streamMessages(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snap.hasData) return const SizedBox();

                final messages = snap.data!.docs
                    .map((d) => Message.fromFirestore(d.data()))
                    .toList();

                if (messages.isEmpty) {
                  return const Center(child: Text('Start the conversation…'));
                }

                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (_, i) => MessageBubble(message: messages[i]),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          MessageInput(controller: _controller, onSend: _onSend),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearHistory,
              label: const Text('Clear history'),
            ),
          ),
        ],
      ),
    );
  }
}
