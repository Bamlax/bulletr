import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../providers/bujo_provider.dart';
import '../models/bullet.dart';
import '../models/collection.dart'; // 引入 Collection 模型
import '../widgets/bujo_drawer.dart';
import '../widgets/bujo_date_picker.dart';

class DailyView extends StatefulWidget {
  const DailyView({super.key});

  @override
  State<DailyView> createState() => _DailyViewState();
}

class _DailyViewState extends State<DailyView> {
  late PageController _pageController;
  late DateTime _displayedDate;
  final DateTime _anchorDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  final int _anchorIndex = 1000;

  @override
  void initState() {
    super.initState();
    final rawFocusDate = Provider.of<BujoProvider>(context, listen: false).focusDate;
    final focusDate = DateTime(rawFocusDate.year, rawFocusDate.month, rawFocusDate.day);
    _displayedDate = focusDate;
    final diffDays = focusDate.difference(_anchorDate).inDays;
    _pageController = PageController(initialPage: _anchorIndex + diffDays);
  }

  @override
  Widget build(BuildContext context) {
    final titleString = DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN').format(_displayedDate);

    return Scaffold(
      drawer: const BujoDrawer(),
      appBar: AppBar(
        title: Text(titleString, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          final newDate = _anchorDate.add(Duration(days: index - _anchorIndex));
          setState(() { _displayedDate = newDate; });
          Provider.of<BujoProvider>(context, listen: false).setFocusDate(newDate);
        },
        itemBuilder: (context, index) {
          final date = _anchorDate.add(Duration(days: index - _anchorIndex));
          return _buildSingleDayPage(date);
        },
      ),
    );
  }

  Widget _buildSingleDayPage(DateTime date) {
    return Consumer<BujoProvider>(
      builder: (context, provider, child) {
        final bullets = provider.getBulletsByScope(date, BulletScope.day);
        
        if (bullets.isEmpty) {
          return Center(child: Text("点击 + 添加计划", style: TextStyle(color: Colors.grey[300], fontSize: 20)));
        }
        
        // 【核心修改】包裹 SlidableAutoCloseBehavior，实现互斥
        return SlidableAutoCloseBehavior(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(top: 10, bottom: 80),
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) => provider.reorderDailyBullets(date, oldIndex, newIndex),
            itemCount: bullets.length,
            itemBuilder: (context, index) {
              final b = bullets[index];
              return ReorderableDelayedDragStartListener(
                key: ValueKey(b.id),
                index: index,
                child: Slidable(
                  key: ValueKey(b.id),
                  groupTag: 'daily_list', // 同一组互斥
                  endActionPane: ActionPane(
                    motion: const ScrollMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (ctx) => _pickNewDate(ctx, provider, b),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        icon: Icons.calendar_today,
                        // 【修改】去掉了 label
                      ),
                      SlidableAction(
                        onPressed: (ctx) => provider.deleteBullet(b.id),
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        icon: Icons.delete,
                        // 【修改】去掉了 label
                      ),
                    ],
                  ),
                  child: _buildListItem(context, provider, b),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _pickNewDate(BuildContext context, BujoProvider provider, Bullet b) async {
    final result = await showBujoDatePicker(
      context, 
      initialDate: b.date ?? DateTime.now(), 
      initialScope: b.scope
    );
    if (result != null) {
      if (result.date == null) {
        // 清除日期 -> 收集箱 (保留原集子ID 或设为 null? 这里设为 null 更纯粹)
        provider.updateBulletFull(b.id, content: b.content, type: b.type, date: null, scope: BulletScope.none, collectionId: null);
      } else {
        provider.moveBullet(b, result.date!, result.scope);
      }
    }
  }

  Widget _buildListItem(BuildContext context, BujoProvider provider, Bullet b) {
    return Material(
      color: Colors.transparent, 
      child: InkWell(
        onTap: () => _showEditDialog(context, b),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
          child: Row(
            children: [
              GestureDetector(
                onTap: b.type == 'task' ? () => provider.toggleStatus(b.id) : null,
                child: Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    _getIcon(b),
                    // 【修改】如果是 Task 且未完成，显示黑色
                    color: (b.type == 'task' && !b.isCompleted) ? Colors.black : Colors.grey,
                    size: 14, // 稍微调小一点，像个点
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  b.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    decoration: b.isCompleted ? TextDecoration.lineThrough : null,
                    color: b.isCompleted ? Colors.grey : Colors.black87,
                    fontSize: 15,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 【核心修改】全功能编辑对话框
  void _showEditDialog(BuildContext context, Bullet bullet) {
    final controller = TextEditingController(text: bullet.content);
    final provider = Provider.of<BujoProvider>(context, listen: false);
    
    // 临时状态
    String selectedType = bullet.type;
    DateTime? selectedDate = bullet.date;
    BulletScope selectedScope = bullet.scope;
    String? selectedCollectionId = bullet.collectionId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          // 获取集子名字用于显示
          String collectionName = "集子";
          if (selectedCollectionId != null) {
             final c = provider.collections.firstWhere((e) => e.id == selectedCollectionId, orElse: () => Collection(id:'', name:'未知'));
             collectionName = c.name;
          }

          // 获取日期字符串用于显示
          String dateStr = "日期";
          if (selectedDate != null) {
             dateStr = DateFormat('MM-dd').format(selectedDate!);
          }

          return AlertDialog(
            title: const Text("编辑任务"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: "内容")),
                const SizedBox(height: 20),
                // 第一行：类型
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTypeOption('task', Icons.fiber_manual_record, selectedType, (val) => setState(() => selectedType = val)),
                    _buildTypeOption('event', Icons.radio_button_unchecked, selectedType, (val) => setState(() => selectedType = val)),
                    _buildTypeOption('note', Icons.remove, selectedType, (val) => setState(() => selectedType = val)),
                  ],
                ),
                const SizedBox(height: 15),
                // 第二行：日期和集子
                Row(
                  children: [
                    Expanded(
                      child: _buildStyledOption(
                        icon: Icons.calendar_today,
                        label: dateStr,
                        onTap: () async {
                          final res = await showBujoDatePicker(context, initialDate: selectedDate ?? DateTime.now(), initialScope: selectedScope);
                          if (res != null) {
                            setState(() {
                              selectedDate = res.date;
                              selectedScope = res.scope;
                            });
                          }
                        }
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStyledOption(
                        icon: Icons.folder_open,
                        label: collectionName,
                        isHighLighted: selectedCollectionId != null,
                        onTap: () {
                          // 简单的集子选择弹窗
                          showModalBottomSheet(context: context, builder: (_) => ListView(
                            shrinkWrap: true,
                            children: [
                              ...provider.collections.map((c) => ListTile(
                                title: Text(c.name),
                                onTap: () {
                                  setState(() => selectedCollectionId = c.id);
                                  Navigator.pop(context);
                                },
                              )),
                              if (selectedCollectionId != null)
                                ListTile(
                                  title: const Text("移除集子", style: TextStyle(color: Colors.red)),
                                  onTap: () {
                                    setState(() => selectedCollectionId = null);
                                    Navigator.pop(context);
                                  },
                                )
                            ],
                          ));
                        }
                      ),
                    ),
                  ],
                )
              ],
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                onPressed: () {
                  provider.deleteBullet(bullet.id);
                  Navigator.pop(ctx);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("删除"),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    provider.updateBulletFull(
                      bullet.id, 
                      content: controller.text, 
                      type: selectedType,
                      date: selectedDate,
                      scope: selectedScope,
                      collectionId: selectedCollectionId
                    );
                    Navigator.pop(ctx);
                  }
                },
                child: const Text("保存"),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStyledOption({required IconData icon, required String label, bool isHighLighted = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isHighLighted ? Colors.blue : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isHighLighted ? Colors.white : Colors.grey),
            const SizedBox(width: 4),
            Flexible(child: Text(label, style: TextStyle(fontSize: 12, color: isHighLighted ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption(String type, IconData icon, String current, Function(String) onTap) {
    final isSelected = type == current;
    return GestureDetector(
      onTap: () => onTap(type),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isSelected ? Colors.blue : Colors.transparent),
        ),
        child: Icon(icon, color: isSelected ? Colors.blue : Colors.grey, size: 18), // 图标稍微调大一点
      ),
    );
  }

  IconData _getIcon(Bullet b) {
    // 【修改】实心黑点逻辑
    if (b.type == 'task') {
      if (b.isCompleted) return Icons.close; // 完成显示X
      return Icons.circle; // 未完成显示实心圆
    }
    if (b.type == 'event') return Icons.radio_button_unchecked; // 空心圆
    if (b.type == 'note') return Icons.remove; // 横杠
    return Icons.circle;
  }
}