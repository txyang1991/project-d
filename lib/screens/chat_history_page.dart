// lib/screens/chat_history_page.dart
// Displays previous messages (mocked for now)

import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../widgets/message_bubble.dart';

class ChatHistoryPage extends StatelessWidget {
  const ChatHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final dummyHistory = [
      Message(text: 'What is carving in snowboarding?', isUser: true, timestamp: DateTime.now()),
      Message(text: 'Carving is a technique where you...', isUser: false, timestamp: DateTime.now()),
      Message(text: 'How do I land a jump?', isUser: true, timestamp: DateTime.now()),
      Message(text: 'Keep your knees bent and spot...', isUser: false, timestamp: DateTime.now()),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dummyHistory.length,
      itemBuilder: (context, index) =>
          MessageBubble(message: dummyHistory[index]),
    );
  }
}
