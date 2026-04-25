class ChatMessage {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isUser;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.isUser,
  });
}
