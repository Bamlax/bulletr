import 'dart:convert';

// 【新增】任务状态枚举
enum BulletStatus { open, completed, cancelled }

enum BulletScope { day, week, month, year, none }

class Bullet {
  final String id;
  String content;
  DateTime? date;      
  // 【修改】替换 isCompleted 为 status
  BulletStatus status;
  String type;        
  BulletScope scope;   
  String? collectionId; 

  Bullet({
    required this.id,
    required this.content,
    this.date, 
    // 默认为 open
    this.status = BulletStatus.open,
    this.type = 'task',
    this.scope = BulletScope.day,
    this.collectionId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'date': date?.toIso8601String(),
      // 【修改】保存 status 的字符串名
      'status': status.name,
      'type': type,
      'scope': scope.name,
      'collectionId': collectionId,
    };
  }

  factory Bullet.fromMap(Map<String, dynamic> map) {
    return Bullet(
      id: map['id'],
      content: map['content'],
      date: map['date'] != null ? DateTime.parse(map['date']) : null,
      // 【修改】读取 status，如果旧数据没有 status 字段，根据 isCompleted 兼容(如果有的话)或默认为 open
      status: map['status'] != null 
          ? BulletStatus.values.firstWhere((e) => e.name == map['status'])
          : (map['isCompleted'] == true ? BulletStatus.completed : BulletStatus.open),
      type: map['type'] ?? 'task',
      scope: BulletScope.values.firstWhere(
        (e) => e.name == map['scope'], 
        orElse: () => BulletScope.day
      ),
      collectionId: map['collectionId'],
    );
  }

  // 辅助属性：是否已完成 (为了兼容某些逻辑，虽然现在有三种状态)
  bool get isCompleted => status == BulletStatus.completed;
  // 辅助属性：是否已取消
  bool get isCancelled => status == BulletStatus.cancelled;

  String toJson() => json.encode(toMap());
  
  factory Bullet.fromJson(String source) => Bullet.fromMap(json.decode(source));
}