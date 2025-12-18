import 'dart:convert';

class Collection {
  final String id;
  String name;
  DateTime updatedAt; // 【新增】修改时间

  Collection({
    required this.id, 
    required this.name,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Collection.fromMap(Map<String, dynamic> map) {
    return Collection(
      id: map['id'],
      name: map['name'],
      updatedAt: map['updatedAt'] != null 
          ? DateTime.parse(map['updatedAt']) 
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());
  factory Collection.fromJson(String source) => Collection.fromMap(json.decode(source));
}