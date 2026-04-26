import '../entities/user_fact.dart';
import '../repositories/i_user_facts_repository.dart';

class FetchUserFactsUseCase {
  final IUserFactsRepository repository;

  FetchUserFactsUseCase(this.repository);

  Future<List<UserFact>> call() async {
    return await repository.getAllFacts();
  }
}
