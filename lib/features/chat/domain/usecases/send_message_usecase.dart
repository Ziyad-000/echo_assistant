import '../entities/chat_message.dart';
import '../repositories/i_chat_repository.dart';

class SendMessageUseCase {
  final IChatRepository repository;

  SendMessageUseCase(this.repository);

  Future<ChatMessage> call(String text, String chatId) async {
    return await repository.sendMessage(text, chatId);
  }
}
