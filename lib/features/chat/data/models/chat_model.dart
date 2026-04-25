import '../../domain/entities/chat_message.dart';

class ChatModel extends ChatMessage {
  const ChatModel({
    required super.id,
    required super.text,
    required super.timestamp,
    required super.isUser,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'] as String,
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isUser: json['isUser'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isUser': isUser,
    };
  }
}
