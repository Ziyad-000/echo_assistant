import 'package:equatable/equatable.dart';

class UserFact extends Equatable {
  final int? id;
  final String key;
  final String value;
  final String category;
  final DateTime updatedAt;

  const UserFact({
    this.id,
    required this.key,
    required this.value,
    required this.category,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id, key, value, category, updatedAt];
}
