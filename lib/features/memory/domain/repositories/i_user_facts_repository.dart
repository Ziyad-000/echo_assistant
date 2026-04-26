import '../entities/user_fact.dart';

abstract class IUserFactsRepository {
  Future<void> saveFact(String key, String value, String category);
  Future<List<UserFact>> getAllFacts();
}
