import '../entities/chat_session.dart';
import '../repositories/i_chat_repository.dart';

class GetHistoryChatsUseCase {
  final IChatRepository repository;

  GetHistoryChatsUseCase(this.repository);

  Future<List<ChatSession>> call() async {
    return await repository.getHistoryChats();
  }
}
