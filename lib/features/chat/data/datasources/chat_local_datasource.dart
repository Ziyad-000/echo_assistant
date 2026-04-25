import '../../../../core/database/database_helper.dart';
import '../models/chat_message_model.dart';
import '../models/chat_session_model.dart';

abstract class IChatLocalDataSource {
  Future<void> saveMessage(ChatMessageModel message);
  Future<void> createChat(ChatSessionModel chat);
  Future<List<ChatSessionModel>> getChats();
  Future<List<ChatMessageModel>> getMessages(String chatId);
  Future<void> deleteChat(String chatId);
  Future<void> updateChatTitle(String chatId, String title);
}

class ChatLocalDataSourceImpl implements IChatLocalDataSource {
  final DatabaseHelper _databaseHelper;

  ChatLocalDataSourceImpl({required DatabaseHelper databaseHelper})
    : _databaseHelper = databaseHelper;

  @override
  Future<void> saveMessage(ChatMessageModel message) async {
    final db = await _databaseHelper.database;
    await db.insert('messages', message.toMap());
  }

  @override
  Future<void> createChat(ChatSessionModel chat) async {
    final db = await _databaseHelper.database;
    await db.insert('chats', chat.toMap());
  }

  @override
  Future<List<ChatSessionModel>> getChats() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chats',
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => ChatSessionModel.fromMap(maps[i]));
  }

  @override
  Future<List<ChatMessageModel>> getMessages(String chatId) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'timestamp ASC',
    );
    return List.generate(maps.length, (i) => ChatMessageModel.fromMap(maps[i]));
  }

  @override
  Future<void> deleteChat(String chatId) async {
    final db = await _databaseHelper.database;
    await db.delete('chats', where: 'id = ?', whereArgs: [chatId]);
    await db.delete('messages', where: 'chat_id = ?', whereArgs: [chatId]);
  }

  @override
  Future<void> updateChatTitle(String chatId, String title) async {
    final db = await _databaseHelper.database;
    await db.update(
      'chats',
      {'title': title},
      where: 'id = ?',
      whereArgs: [chatId],
    );
  }
}
