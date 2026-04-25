import '../entities/chat_session.dart';
import '../repositories/i_chat_repository.dart';

class CreateNewChatUseCase {
  final IChatRepository repository;

  CreateNewChatUseCase(this.repository);

  Future<ChatSession> call() async {
    return await repository.createNewChat();
  }
}
