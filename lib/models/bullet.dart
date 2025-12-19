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
  DateTime updatedAt; // 【新增】修改时间

  Bullet({
    required this.id,
    required this.content,
    this.date, 
    this.status = BulletStatus.open,
    this.type = 'task',
    this.scope = BulletScope.day,
    this.collectionId,
    DateTime? updatedAt, // 可选参数
  }) : updatedAt = updatedAt ?? DateTime.now(); // 默认为当前时间

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'date': date?.toIso8601String(),
      'status': status.name,
      'type': type,
      'scope': scope.name,
      'collectionId': collectionId,
      'updatedAt': updatedAt.toIso8601String(), // 保存时间
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
      // 读取时间，如果是旧数据没有这个字段，就给个当前时间
      updatedAt: map['updatedAt'] != null 
          ? DateTime.parse(map['updatedAt']) 
          : DateTime.now(),
    );
  }

  // 辅助属性
  bool get isCompleted => status == BulletStatus.completed;
  bool get isCancelled => status == BulletStatus.cancelled;

  String toJson() => json.encode(toMap());
  
  factory Bullet.fromJson(String source) => Bullet.fromMap(json.decode(source));
}