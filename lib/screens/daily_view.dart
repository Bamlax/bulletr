import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../providers/bujo_provider.dart';
import '../models/bullet.dart';
import '../models/collection.dart';
import '../widgets/bujo_drawer.dart';
import '../widgets/bujo_date_picker.dart'; // 必须引入这个

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
                  groupTag: 'daily_list',
                  endActionPane: ActionPane(
                    motion: const ScrollMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (ctx) => _pickNewDate(ctx, provider, b),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        icon: Icons.calendar_today,
                      ),
                      SlidableAction(
                        onPressed: (ctx) => provider.deleteBullet(b.id),
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        icon: Icons.delete,
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
                    color: (b.type == 'task' && !b.isCompleted) ? Colors.black : Colors.grey,
                    size: 14,
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

  // 【核心修复】正确的日期显示逻辑
  void _showEditDialog(BuildContext context, Bullet bullet) {
    final controller = TextEditingController(text: bullet.content);
    final provider = Provider.of<BujoProvider>(context, listen: false);
    
    String selectedType = bullet.type;
    DateTime? selectedDate = bullet.date;
    BulletScope selectedScope = bullet.scope;
    String? selectedCollectionId = bullet.collectionId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          String collectionName = "集子";
          if (selectedCollectionId != null) {
             final c = provider.collections.firstWhere((e) => e.id == selectedCollectionId, orElse: () => Collection(id:'', name:'未知'));
             collectionName = c.name;
          }

          // --- 修复部分：根据 scope 显示正确的日期格式 ---
          String dateStr = "日期";
          if (selectedDate != null) {
            if (selectedScope == BulletScope.day) {
              dateStr = DateFormat('MM-dd').format(selectedDate!);
            } else if (selectedScope == BulletScope.week) {
              dateStr = "第${calculateWeekNumber(selectedDate!)}周"; // 使用工具函数
            } else if (selectedScope == BulletScope.month) {
              dateStr = "${selectedDate!.month}月";
            } else if (selectedScope == BulletScope.year) {
              dateStr = "${selectedDate!.year}年";
            }
          }
          // ------------------------------------------

          return AlertDialog(
            title: const Text("编辑任务"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: "内容")),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _buildTypeOption('task', Icons.fiber_manual_record, selectedType, (val) => setState(() => selectedType = val)),
                  _buildTypeOption('event', Icons.radio_button_unchecked, selectedType, (val) => setState(() => selectedType = val)),
                  _buildTypeOption('note', Icons.remove, selectedType, (val) => setState(() => selectedType = val)),
                ]),
                const SizedBox(height: 15),
                Row(children: [
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
                              ListTile(title: const Text("移除集子", style: TextStyle(color: Colors.red)), onTap: () { setState(() => selectedCollectionId = null); Navigator.pop(context); })
                          ],
                        ));
                      }
                    ),
                  ),
                ])
              ],
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(onPressed: () { provider.deleteBullet(bullet.id); Navigator.pop(ctx); }, style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text("删除")),
              ElevatedButton(onPressed: () {
                if (controller.text.isNotEmpty) {
                  provider.updateBulletFull(bullet.id, content: controller.text, type: selectedType, date: selectedDate, scope: selectedScope, collectionId: selectedCollectionId);
                  Navigator.pop(ctx);
                }
              }, child: const Text("保存")),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStyledOption({required IconData icon, required String label, bool isHighLighted = false, required VoidCallback onTap}) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8), decoration: BoxDecoration(color: isHighLighted ? Colors.blue : Colors.grey[100], borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 16, color: isHighLighted ? Colors.white : Colors.grey), const SizedBox(width: 4), Flexible(child: Text(label, style: TextStyle(fontSize: 12, color: isHighLighted ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis))])));
  }
  Widget _buildTypeOption(String type, IconData icon, String current, Function(String) onTap) {
    return GestureDetector(onTap: () => onTap(type), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: type == current ? Colors.blue.withValues(alpha: 0.1) : Colors.transparent, borderRadius: BorderRadius.circular(4), border: Border.all(color: type == current ? Colors.blue : Colors.transparent)), child: Icon(icon, color: type == current ? Colors.blue : Colors.grey, size: 18)));
  }
  IconData _getIcon(Bullet b) {
    if (b.type == 'task') return b.isCompleted ? Icons.check_circle : Icons.circle;
    if (b.type == 'event') return Icons.radio_button_unchecked;
    if (b.type == 'note') return Icons.remove;
    return Icons.circle;
  }
}