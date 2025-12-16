enum BulletScope { day, week, month, year, none } // 增加 none 用于无时间维度的任务

class Bullet {
  final String id;
  String content;
  DateTime? date;      // 【修改】变成可空。如果为空，说明不在日历视图显示
  bool isCompleted;
  String type;        
  BulletScope scope;   
  String? collectionId; // 【新增】所属集子ID。如果为 null 且 date 为 null，就是“收集箱”

  Bullet({
    required this.id,
    required this.content,
    this.date, // 可空
    this.isCompleted = false,
    this.type = 'task',
    this.scope = BulletScope.day,
    this.collectionId,
  });
}