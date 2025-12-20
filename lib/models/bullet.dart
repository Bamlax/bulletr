import 'dart:convert';

enum BulletStatus { open, completed, cancelled }

enum BulletScope { day, week, month, year, none }

class Bullet {
  final String id;
  String content;
  DateTime? date;      
  BulletStatus status;
  String type;        
  BulletScope scope;   
  String? collectionId; 
  DateTime updatedAt;
  String? parentId; // 【新增】父任务ID

  Bullet({
    required this.id,
    required this.content,
    this.date, 
    this.status = BulletStatus.open,
    this.type = 'task',
    this.scope = BulletScope.day,
    this.collectionId,
    DateTime? updatedAt,
    this.parentId, // 【新增】
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'date': date?.toIso8601String(),
      'status': status.name,
      'type': type,
      'scope': scope.name,
      'collectionId': collectionId,
      'updatedAt': updatedAt.toIso8601String(),
      'parentId': parentId, // 【新增】
    };
  }

  factory Bullet.fromMap(Map<String, dynamic> map) {
    return Bullet(
      id: map['id'],
      content: map['content'],
      date: map['date'] != null ? DateTime.parse(map['date']) : null,
      status: map['status'] != null 
          ? BulletStatus.values.firstWhere((e) => e.name == map['status'])
          : (map['isCompleted'] == true ? BulletStatus.completed : BulletStatus.open),
      type: map['type'] ?? 'task',
      scope: BulletScope.values.firstWhere(
        (e) => e.name == map['scope'], 
        orElse: () => BulletScope.day
      ),
      collectionId: map['collectionId'],
      updatedAt: map['updatedAt'] != null 
          ? DateTime.parse(map['updatedAt']) 
          : DateTime.now(),
      parentId: map['parentId'], // 【新增】
    );
  }

  bool get isCompleted => status == BulletStatus.completed;
  bool get isCancelled => status == BulletStatus.cancelled;

  String toJson() => json.encode(toMap());
  factory Bullet.fromJson(String source) => Bullet.fromMap(json.decode(source));
}