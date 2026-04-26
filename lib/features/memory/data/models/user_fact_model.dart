import '../../domain/entities/user_fact.dart';

class UserFactModel extends UserFact {
  const UserFactModel({
    super.id,
    required super.key,
    required super.value,
    required super.category,
    required super.updatedAt,
  });

  factory UserFactModel.fromJson(Map<String, dynamic> json) {
    return UserFactModel(
      id: json['id'] as int?,
      key: json['key'] as String,
      value: json['value'] as String,
      category: json['category'] as String,
      // SQLite stores timestamps as INTEGER
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'key': key,
      'value': value,
      'category': category,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory UserFactModel.fromEntity(UserFact entity) {
    return UserFactModel(
      id: entity.id,
      key: entity.key,
      value: entity.value,
      category: entity.category,
      updatedAt: entity.updatedAt,
    );
  }
}
