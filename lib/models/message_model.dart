// message_model.dart
// Defines the structure of a single chat message (text, sender, timestamp)

class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  Message({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
