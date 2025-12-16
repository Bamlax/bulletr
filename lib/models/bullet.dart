import 'dart:convert';

enum BulletScope { day, week, month, year, none }

class Bullet {
  final String id;
  String content;
  DateTime? date;      
  bool isCompleted;
  String type;        
  BulletScope scope;   
  String? collectionId; 

  Bullet({
    required this.id,
    required this.content,
    this.date, 
    this.isCompleted = false,
    this.type = 'task',
    this.scope = BulletScope.day,
    this.collectionId,
  });

  // --- 序列化逻辑 ---

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      // 日期转为 ISO8601 字符串存储，如果是 null 则存 null
      'date': date?.toIso8601String(),
      'isCompleted': isCompleted,
      'type': type,
      // 枚举转为字符串存储 (例如 "BulletScope.day" -> "day")
      'scope': scope.name,
      'collectionId': collectionId,
    };
  }

  factory Bullet.fromMap(Map<String, dynamic> map) {
    return Bullet(
      id: map['id'],
      content: map['content'],
      // 字符串转回 DateTime
      date: map['date'] != null ? DateTime.parse(map['date']) : null,
      isCompleted: map['isCompleted'] ?? false,
      type: map['type'] ?? 'task',
      // 字符串转回 Enum
      scope: BulletScope.values.firstWhere(
        (e) => e.name == map['scope'], 
        orElse: () => BulletScope.day
      ),
      collectionId: map['collectionId'],
    );
  }

  String toJson() => json.encode(toMap());
  
  factory Bullet.fromJson(String source) => Bullet.fromMap(json.decode(source));
}