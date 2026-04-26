import '../repositories/i_user_facts_repository.dart';

class SaveUserFactUseCase {
  final IUserFactsRepository repository;

  SaveUserFactUseCase(this.repository);

  Future<void> call(String key, String value, String category) async {
    await repository.saveFact(key, value, category);
  }
}
