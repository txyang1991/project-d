// lib/screens/main_page.dart
// Page where users ask questions and receive AI responses

import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Message> _messages = [];

  void _askQuestion() {
    final question = _controller.text.trim();
    if (question.isEmpty) return;

    setState(() {
      _messages.add(Message(
        text: question,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _messages.add(Message(
        text: 'Answer to: "$question"',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) =>
                  MessageBubble(message: _messages[index]),
            ),
          ),
          const SizedBox(height: 8),
          MessageInput(controller: _controller, onSend: _askQuestion),
        ],
      ),
    );
  }
}
