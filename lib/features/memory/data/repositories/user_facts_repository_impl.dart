import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../../domain/entities/user_fact.dart';
import '../../domain/repositories/i_user_facts_repository.dart';
import '../models/user_fact_model.dart';

class UserFactsRepositoryImpl implements IUserFactsRepository {
  final DatabaseHelper databaseHelper;

  UserFactsRepositoryImpl({required this.databaseHelper});

  @override
  Future<void> saveFact(String key, String value, String category) async {
    final db = await databaseHelper.database;
    final model = UserFactModel(
      key: key,
      value: value,
      category: category,
      updatedAt: DateTime.now(),
    );

    // Using UPSERT: conflictAlgorithm.replace will replace the existing row
    // if the UNIQUE constraint on 'key' is violated.
    await db.insert(
      'user_facts',
      model.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<UserFact>> getAllFacts() async {
    final db = await databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_facts',
      orderBy: 'updated_at DESC',
    );

    return List.generate(maps.length, (i) {
      return UserFactModel.fromJson(maps[i]);
    });
  }
}
