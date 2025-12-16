import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/bujo_provider.dart';
import '../models/bullet.dart';
import '../models/collection.dart';
import '../widgets/bujo_drawer.dart';
import '../widgets/bujo_date_picker.dart';

class WeeklyView extends StatefulWidget {
  final VoidCallback onJumpToDay;
  const WeeklyView({super.key, required this.onJumpToDay});
  @override
  State<WeeklyView> createState() => _WeeklyViewState();
}

class _WeeklyViewState extends State<WeeklyView> {
  late PageController _pageController;
  late DateTime _displayedWeekStart;
  late DateTime _anchorMonday;
  final int _anchorIndex = 1000;
  final List<String> _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchorMonday = now.subtract(Duration(days: now.weekday - 1));
    _displayedWeekStart = _anchorMonday;
    _pageController = PageController(initialPage: _anchorIndex);
  }

  @override
  Widget build(BuildContext context) {
    final year = _displayedWeekStart.year;
    final weekNum = calculateWeekNumber(_displayedWeekStart);
    final endOfWeek = _displayedWeekStart.add(const Duration(days: 6));
    final rangeStr = "${DateFormat('MM.dd').format(_displayedWeekStart)} - ${DateFormat('MM.dd').format(endOfWeek)}";

    return Scaffold(
      drawer: const BujoDrawer(),
      appBar: AppBar(
        title: Column(children: [
          Text("$year年 第$weekNum周", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(rangeStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1.0), child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE))),
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() { _displayedWeekStart = _anchorMonday.add(Duration(days: (index - _anchorIndex) * 7)); });
          Provider.of<BujoProvider>(context, listen: false).setFocusDate(_displayedWeekStart);
        },
        itemBuilder: (context, index) {
          final weekStart = _anchorMonday.add(Duration(days: (index - _anchorIndex) * 7));
          return _buildSingleWeekPage(weekStart);
        },
      ),
    );
  }

  Widget _buildSingleWeekPage(DateTime weekStart) {
    return Column(
      children: [
        _buildWeeklyPool(weekStart),
        Expanded(
          child: Container(
            color: Colors.white,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: 7,
              itemBuilder: (context, i) {
                final dayDate = weekStart.add(Duration(days: i));
                return _buildDayDropTarget(dayDate);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyPool(DateTime weekStart) {
    return DragTarget<Bullet>(
      onAcceptWithDetails: (details) {
        Provider.of<BujoProvider>(context, listen: false).moveBullet(details.data, weekStart, BulletScope.week);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Consumer<BujoProvider>(
          builder: (context, provider, _) {
            final weeklyBullets = provider.getBulletsByScope(weekStart, BulletScope.week);
            // 保证有足够的空间接收拖拽
            if (weeklyBullets.isEmpty && !isHovering) return Container(height: 20, width: double.infinity, color: Colors.transparent);

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isHovering ? Colors.blue.withValues(alpha: 0.1) : const Color(0xFFF5F9FF),
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (weeklyBullets.isNotEmpty) ...weeklyBullets.map((b) => _buildDraggablePoolStrip(b)),
                  if (isHovering) const Center(child: Text("放回到本周任务", style: TextStyle(color: Colors.blue, fontSize: 12))),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDayDropTarget(DateTime date) {
    final isToday = DateFormat('yyyyMMdd').format(date) == DateFormat('yyyyMMdd').format(DateTime.now());
    final weekdayChar = _weekdays[date.weekday - 1];
    final dayNum = date.day.toString();

    return DragTarget<Bullet>(
      onAcceptWithDetails: (details) {
        Provider.of<BujoProvider>(context, listen: false).moveBullet(details.data, date, BulletScope.day);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: isHovering ? Colors.blue.withValues(alpha: 0.1) : (isToday ? const Color(0xFFFFFDE7) : Colors.transparent),
            border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () {
                  Provider.of<BujoProvider>(context, listen: false).setFocusDate(date);
                  widget.onJumpToDay();
                },
                child: Container(
                  width: 60, padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[100]!))),
                  child: Column(children: [
                    Text(dayNum, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isToday ? Colors.blue : Colors.black87)),
                    Text(weekdayChar, style: TextStyle(fontSize: 12, color: isToday ? Colors.blue : Colors.grey)),
                  ]),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: Consumer<BujoProvider>(
                    builder: (ctx, provider, _) {
                      final dayBullets = provider.getBulletsByScope(date, BulletScope.day);
                      if (dayBullets.isEmpty) return const SizedBox(height: 36);
                      return Column(children: dayBullets.map((b) => _buildDraggableStrip(b)).toList());
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 拖拽样式修复：全宽长条 ---
  Widget _buildDraggableStrip(Bullet bullet) {
    return LongPressDraggable<Bullet>(
      data: bullet,
      feedback: Material(
        color: Colors.transparent,
        elevation: 4,
        child: Container(
          width: MediaQuery.of(context).size.width - 80, // 屏幕宽度减去左侧日期宽
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
          child: _buildStripContent(bullet, isDragging: true),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _buildStripContent(bullet)),
      child: _buildStripContent(bullet),
    );
  }

  // 顶部池子也用类似逻辑
  Widget _buildDraggablePoolStrip(Bullet bullet) {
    return LongPressDraggable<Bullet>(
      data: bullet,
      feedback: Material(
        color: Colors.transparent,
        elevation: 4,
        child: Container(
          width: MediaQuery.of(context).size.width - 32,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
          child: _buildStripContent(bullet, isDragging: true),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _buildStripContent(bullet)),
      child: _buildStripContent(bullet),
    );
  }

  Widget _buildStripContent(Bullet bullet, {bool isDragging = false}) {
    // 只有非拖拽状态才响应点击
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDragging ? null : () => _showEditDialog(context, bullet),
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(_getIcon(bullet), size: 14, color: (bullet.type == 'task' && !bullet.isCompleted) ? Colors.black : Colors.grey),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(bullet.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, height: 1.2, decoration: bullet.isCompleted ? TextDecoration.lineThrough : null, color: bullet.isCompleted ? Colors.grey : Colors.black87)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon(Bullet b) {
    if (b.type == 'task') return b.isCompleted ? Icons.check_circle : Icons.circle;
    if (b.type == 'event') return Icons.radio_button_unchecked;
    if (b.type == 'note') return Icons.remove;
    return Icons.circle;
  }

  // --- 编辑弹窗：修复日期显示 ---
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
          String collectionName = selectedCollectionId != null 
              ? provider.collections.firstWhere((e) => e.id == selectedCollectionId, orElse: () => Collection(id:'', name:'未知')).name 
              : "集子";
          
          // 【核心修复】正确的日期/周数显示
          String dateStr = "日期";
          if (selectedDate != null) {
            if (selectedScope == BulletScope.day) dateStr = DateFormat('MM-dd').format(selectedDate!);
            else if (selectedScope == BulletScope.week) dateStr = "第${calculateWeekNumber(selectedDate!)}周";
            else if (selectedScope == BulletScope.month) dateStr = "${selectedDate!.month}月";
            else if (selectedScope == BulletScope.year) dateStr = "${selectedDate!.year}年";
          }

          return AlertDialog(
            title: const Text("编辑任务"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: controller, autofocus: true),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _buildTypeOption('task', Icons.fiber_manual_record, selectedType, (val) => setState(() => selectedType = val)),
                  _buildTypeOption('event', Icons.radio_button_unchecked, selectedType, (val) => setState(() => selectedType = val)),
                  _buildTypeOption('note', Icons.remove, selectedType, (val) => setState(() => selectedType = val)),
                ]),
                const SizedBox(height: 15),
                Row(children: [
                  Expanded(child: _buildStyledOption(icon: Icons.calendar_today, label: dateStr, onTap: () async {
                    final res = await showBujoDatePicker(context, initialDate: selectedDate ?? DateTime.now(), initialScope: selectedScope);
                    if (res != null) setState(() { selectedDate = res.date; selectedScope = res.scope; });
                  })),
                  const SizedBox(width: 10),
                  Expanded(child: _buildStyledOption(icon: Icons.folder_open, label: collectionName, isHighLighted: selectedCollectionId != null, onTap: () {
                    showModalBottomSheet(context: context, builder: (_) => ListView(shrinkWrap: true, children: [
                      ...provider.collections.map((c) => ListTile(title: Text(c.name), onTap: () { setState(() => selectedCollectionId = c.id); Navigator.pop(context); })),
                      if (selectedCollectionId != null) ListTile(title: const Text("移除集子", style: TextStyle(color: Colors.red)), onTap: () { setState(() => selectedCollectionId = null); Navigator.pop(context); })
                    ]));
                  })),
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
}