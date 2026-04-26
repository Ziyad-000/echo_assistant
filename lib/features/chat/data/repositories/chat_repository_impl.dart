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
  }) async {
    // 1. Check if it's the first message, update chat title
    final existingMessages = await localDataSource.getMessages(chatId);
    if (existingMessages.isEmpty) {
      final title =
          text.split(' ').take(3).join(' ') +
          (text.split(' ').length > 3 ? '...' : '');
      await localDataSource.updateChatTitle(chatId, title);
    }

    // 2. Create and cache user message
    final userMessage = ChatMessageModel(
      id: _uuid.v4(),
      chatId: chatId,
      text: text,
      timestamp: DateTime.now(),
      isUser: true,
    );
    await localDataSource.saveMessage(userMessage);

    // 3. Check network connectivity
    if (!await networkInfo.isConnected) {
      throw ServerException('No Internet Connection');
    }

    try {
      // Create history map
      final history = existingMessages
          .map((m) => {'content': m.text, 'is_user': m.isUser ? 1 : 0})
          .toList();

      // 4. Get AI response from remote
      final aiResponse = await remoteDataSource.sendMessage(
        text,
        history: history,
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
