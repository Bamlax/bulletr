class DevLog {
  final String version;
  final String date;
  final List<String> changes;

  DevLog({required this.version, required this.date, required this.changes});
}

// 这里管理你的开发日志数据
final List<DevLog> appDevLogs = [
  DevLog(
    version: "0.1.1",
    date: "2025-12-16",
    changes: [
      "修复数据无法保存的问题",
      "修复版本号的错误显示",
    ],
  ),
  DevLog(
    version: "0.1.0",
    date: "2025-12-16",
    changes: [
      "实现 日/周/月/年 四种核心视图",
      "支持全局长按拖拽排序与跨维度任务分发",
      "引入“集子(Collections)”与“收集箱”系统",
      "新增高级日期选择器 (支持周/月/年 Tab)",
      "增加侧边栏导航与设置页面",
    ],
  ),
  // 以后有新版本在这里往上加
];