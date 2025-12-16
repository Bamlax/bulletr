import 'dart:convert';

class Collection {
  final String id;
  String name;
  
  Collection({required this.id, required this.name});

  // 转成 JSON Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  // 从 JSON Map 转回对象
  factory Collection.fromMap(Map<String, dynamic> map) {
    return Collection(
      id: map['id'],
      name: map['name'],
    );
  }

  //以此为基础转成字符串
  String toJson() => json.encode(toMap());
  
  factory Collection.fromJson(String source) => Collection.fromMap(json.decode(source));
}