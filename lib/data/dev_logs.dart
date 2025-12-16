class DevLog {
  final String version;
  final String date;
  final List<String> changes;

  DevLog({required this.version, required this.date, required this.changes});
}

// 这里管理你的开发日志数据
final List<DevLog> appDevLogs = [
  DevLog(
    version: "1.0.0",
    date: "2023-12-16",
    changes: [
      "App 更名为 bulletr",
      "新增侧滑菜单与自定义集子功能",
      "优化日/周/月/年视图的拖拽交互",
      "新增设置页面与开发者信息",
    ],
  ),
  DevLog(
    version: "0.8.0",
    date: "2023-12-15",
    changes: [
      "实现基础的 CRUD 功能",
      "添加日期选择器",
      "支持任务长按拖拽排序",
    ],
  ),
  // 以后有新版本在这里往上加
];