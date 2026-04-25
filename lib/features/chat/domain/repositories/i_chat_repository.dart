import '../entities/chat_message.dart';
import '../entities/chat_session.dart';

abstract class IChatRepository {
  Future<List<ChatSession>> getHistoryChats();
  Future<List<ChatMessage>> getChatMessages(String chatId);
  Future<ChatSession> createNewChat();
  Future<void> deleteChat(String chatId);
  Future<ChatMessage> sendMessage(String text, String chatId);
}
