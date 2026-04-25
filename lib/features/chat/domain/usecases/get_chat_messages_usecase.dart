import '../entities/chat_message.dart';
import '../repositories/i_chat_repository.dart';

class GetChatMessagesUseCase {
  final IChatRepository repository;

  GetChatMessagesUseCase(this.repository);

  Future<List<ChatMessage>> call(String chatId) async {
    return await repository.getChatMessages(chatId);
  }
}
