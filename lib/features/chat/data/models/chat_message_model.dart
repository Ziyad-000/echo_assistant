import '../../domain/entities/chat_message.dart';

class ChatMessageModel extends ChatMessage {
  final String chatId;

  const ChatMessageModel({
    required super.id,
    required this.chatId,
    required super.text,
    required super.isUser,
    required super.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chat_id': chatId,
      'content': text,
      'is_user': isUser ? 1 : 0,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      id: map['id'] as String,
      chatId: map['chat_id'] as String,
      text: map['content'] as String,
      isUser: map['is_user'] == 1,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}
