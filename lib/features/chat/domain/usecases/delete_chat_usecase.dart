import '../repositories/i_chat_repository.dart';

class DeleteChatUseCase {
  final IChatRepository repository;

  DeleteChatUseCase(this.repository);

  Future<void> call(String chatId) async {
    return await repository.deleteChat(chatId);
  }
}
