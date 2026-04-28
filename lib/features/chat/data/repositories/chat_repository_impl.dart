import 'package:uuid/uuid.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_session.dart';
import '../../domain/repositories/i_chat_repository.dart';
import '../datasources/chat_local_datasource.dart';
import '../datasources/chat_remote_datasource.dart';
import '../models/chat_message_model.dart';
import '../models/chat_session_model.dart';

class ChatRepositoryImpl implements IChatRepository {
  final IChatRemoteDataSource remoteDataSource;
  final IChatLocalDataSource localDataSource;
  final INetworkInfo networkInfo;
  final Uuid _uuid = const Uuid();

  ChatRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<List<ChatSession>> getHistoryChats() async {
    final chats = await localDataSource.getChats();
    return chats.cast<ChatSession>();
  }

  @override
  Future<List<ChatMessage>> getChatMessages(String chatId) async {
    final messages = await localDataSource.getMessages(chatId);
    return messages.cast<ChatMessage>();
  }

  @override
  Future<ChatSession> createNewChat() async {
    final session = ChatSessionModel(
      id: _uuid.v4(),
      title: 'New Chat',
      createdAt: DateTime.now(),
    );
    await localDataSource.createChat(session);
    return session;
  }

  @override
  Future<void> deleteChat(String chatId) async {
    await localDataSource.deleteChat(chatId);
  }

  @override
  Future<ChatMessage> sendMessage(
    String text,
    String chatId, {
    String? systemInstruction,
    bool isRetry = false,
  }) async {
    // 1. Only write the user message to SQLite on first send, not on retry.
    //    This is the guard that prevents duplicate user messages in the DB.
    if (!isRetry) {
      // Check if it's the first message, update chat title
      final existingMessages = await localDataSource.getMessages(chatId);
      if (existingMessages.isEmpty) {
        final title =
            text.split(' ').take(3).join(' ') +
            (text.split(' ').length > 3 ? '...' : '');
        await localDataSource.updateChatTitle(chatId, title);
      }

      // Create and cache user message
      final userMessage = ChatMessageModel(
        id: _uuid.v4(),
        chatId: chatId,
        text: text,
        timestamp: DateTime.now(),
        isUser: true,
      );
      await localDataSource.saveMessage(userMessage);
    }

    // 3. Check network connectivity
    if (!await networkInfo.isConnected) {
      throw ServerException('No Internet Connection');
    }

    try {
      // Fetch all persisted messages to build the conversation history for the AI.
      // This must happen regardless of isRetry so the AI has full context.
      final historyMessages = await localDataSource.getMessages(chatId);
      final history = historyMessages
          .map((m) => {'content': m.text, 'is_user': m.isUser ? 1 : 0})
          .toList();

      // Fix: "History Double-Dip" prevention.
      // The DB now contains the user's current message (just saved above).
      // Gemini's startChat() takes PRIOR context; the current message is sent
      // separately via chatSession.sendMessage(text) inside the datasource.
      // Passing it in history too would cause Gemini to see it twice.
      // We create a shallow copy and trim the last entry to avoid mutating the list.
      final priorHistory = List<Map<String, dynamic>>.from(history);
      if (priorHistory.isNotEmpty) {
        priorHistory.removeLast();
      }

      // 4. Get AI response from remote
      final aiResponse = await remoteDataSource.sendMessage(
        text,
        history: priorHistory,
        systemInstruction: systemInstruction,
      );

      // Convert core ChatModel from Gemini to ChatMessageModel to save
      final aiMessageModel = ChatMessageModel(
        id: _uuid.v4(),
        chatId: chatId,
        text: aiResponse.text,
        timestamp: aiResponse.timestamp,
        isUser: aiResponse.isUser,
      );

      // 5. Cache AI response
      await localDataSource.saveMessage(aiMessageModel);

      return aiMessageModel;
    } catch (e) {
      throw ServerException('Failed to fetch AI response: $e');
    }
  }
}
