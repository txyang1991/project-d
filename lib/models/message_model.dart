import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  Message({required this.text, required this.isUser, required this.timestamp});

  factory Message.fromFirestore(Map<String, dynamic> data) {
    final role = (data['role'] as String?) ?? 'user';
    final ts = data['ts'];
    final when = ts is Timestamp ? ts.toDate() : DateTime.now();
    return Message(
      text: (data['text'] as String?) ?? '',
      isUser: role == 'user',
      timestamp: when,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'role': isUser ? 'user' : 'assistant',
    'text': text,
    'ts': Timestamp.fromDate(timestamp),
  };
}
