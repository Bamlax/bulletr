import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bujo_provider.dart';
import '../models/bullet.dart';
import '../models/collection.dart';
import '../widgets/bujo_drawer.dart';
import '../widgets/bujo_date_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class MonthlyView extends StatefulWidget {
  final VoidCallback onJumpToDay;
  const MonthlyView({super.key, required this.onJumpToDay});
  @override
  State<MonthlyView> createState() => _MonthlyViewState();
}

class _MonthlyViewState extends State<MonthlyView> {
  late PageController _pageController;
  late DateTime _displayedMonth; 
  final int _anchorIndex = 1000;
  final DateTime _anchorDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  final List<String> _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    final rawFocusDate = Provider.of<BujoProvider>(context, listen: false).focusDate;
    _displayedMonth = DateTime(rawFocusDate.year, rawFocusDate.month, 1);
    int monthDiff = (_displayedMonth.year - _anchorDate.year) * 12 + (_displayedMonth.month - _anchorDate.month);
    _pageController = PageController(initialPage: _anchorIndex + monthDiff);
  }

  @override
  Widget build(BuildContext context) {
    final year = _displayedMonth.year;
    final month = _displayedMonth.month;
    return Scaffold(
      drawer: const BujoDrawer(),
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () {
            _pageController.animateToPage(_anchorIndex, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
          },
          child: Text("$year年 $month月", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        centerTitle: true, backgroundColor: Colors.white, elevation: 0, bottom: const PreferredSize(preferredSize: Size.fromHeight(1.0), child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)))),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() { _displayedMonth = DateTime(_anchorDate.year, _anchorDate.month + (index - _anchorIndex), 1); });
          Provider.of<BujoProvider>(context, listen: false).setFocusDate(_displayedMonth);
        },
        itemBuilder: (context, index) {
          final monthDate = DateTime(_anchorDate.year, _anchorDate.month + (index - _anchorIndex), 1);
          return _buildSingleMonthPage(monthDate);
        },
      ),
    );
  }

  Widget _buildSingleMonthPage(DateTime monthDate) {
    return SlidableAutoCloseBehavior(
      child: Column(children: [_buildMonthlyPool(monthDate), Expanded(child: Container(color: Colors.white, child: _buildMonthList(monthDate)))]),
    );
  }

  Widget _buildMonthlyPool(DateTime monthDate) {
    return DragTarget<Bullet>(
      onAcceptWithDetails: (details) {
        Provider.of<BujoProvider>(context, listen: false).moveBullet(details.data, monthDate, BulletScope.month);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Consumer<BujoProvider>(builder: (context, provider, _) {
          final monthlyBullets = provider.getBulletsByScope(monthDate, BulletScope.month);
          if (monthlyBullets.isEmpty && !isHovering) return Container(height: 20, width: double.infinity, color: Colors.transparent);
          return Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: isHovering ? Colors.blue.withValues(alpha: 0.1) : const Color(0xFFF5F9FF), border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (monthlyBullets.isNotEmpty) ...monthlyBullets.map((b) => _buildDraggablePoolStrip(b)),
              if (isHovering) const Center(child: Text("放回到本月任务", style: TextStyle(color: Colors.blue, fontSize: 12))),
            ]),
          );
        });
      },
    );
  }

  Widget _buildDraggablePoolStrip(Bullet bullet) {
    final screenWidth = MediaQuery.of(context).size.width;
    return LongPressDraggable<Bullet>(
      data: bullet,
      feedback: Material(color: Colors.transparent, elevation: 6, child: Container(width: screenWidth * 0.8, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)), child: _buildStripContent(bullet, isDragging: true))),
      childWhenDragging: Opacity(opacity: 0.3, child: _buildStripContent(bullet)),
      child: Slidable(
        key: ValueKey(bullet.id),
        groupTag: 'monthly_pool',
        startActionPane: _buildStartPane(bullet),
        endActionPane: _buildEndPane(bullet),
        child: _buildStripContent(bullet),
      ),
    );
  }

  Widget _buildMonthList(DateTime monthDate) {
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    return ListView.builder(padding: EdgeInsets.zero, itemCount: daysInMonth, itemBuilder: (context, i) {
      final currentDate = DateTime(monthDate.year, monthDate.month, i + 1);
      return _buildDayRow(currentDate);
    });
  }

  Widget _buildDayRow(DateTime date) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final weekdayChar = _weekdays[date.weekday - 1]; 

    return DragTarget<Bullet>(
      onAcceptWithDetails: (details) {
        Provider.of<BujoProvider>(context, listen: false).moveBullet(details.data, date, BulletScope.day);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(color: isHovering ? Colors.blue.withValues(alpha: 0.1) : (isToday ? const Color(0xFFFFFDE7) : Colors.transparent), border: Border(bottom: BorderSide(color: Colors.grey[100]!, width: 1))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              onTap: () { Provider.of<BujoProvider>(context, listen: false).setFocusDate(date); widget.onJumpToDay(); },
              child: Container(width: 50, padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), alignment: Alignment.topCenter, decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[50]!))), child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [Text("${date.day}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isToday ? Colors.blue : Colors.black87)), const SizedBox(width: 2), Text(weekdayChar, style: TextStyle(fontSize: 10, color: isToday ? Colors.blue : Colors.grey))])),
            ),
            Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), child: Consumer<BujoProvider>(builder: (ctx, provider, _) {
              final dayBullets = provider.getBulletsByScope(date, BulletScope.day);
              if (dayBullets.isEmpty) return const SizedBox(height: 20); 
              return Column(children: dayBullets.map((b) => _buildDraggableStrip(b)).toList());
            }))),
          ]),
        );
      },
    );
  }

  Widget _buildDraggableStrip(Bullet bullet) {
    final screenWidth = MediaQuery.of(context).size.width;
    return LongPressDraggable<Bullet>(
      data: bullet,
      feedback: Material(color: Colors.transparent, elevation: 6, child: Container(width: screenWidth - 70, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)), child: _buildStripContent(bullet, isDragging: true))),
      childWhenDragging: Opacity(opacity: 0.3, child: _buildStripContent(bullet)),
      child: Slidable(
        key: ValueKey(bullet.id),
        groupTag: 'monthly_list',
        startActionPane: _buildStartPane(bullet),
        endActionPane: _buildEndPane(bullet),
        child: _buildStripContent(bullet),
      ),
    );
  }

  ActionPane _buildStartPane(Bullet b) {
    return ActionPane(
      motion: const ScrollMotion(),
      children: [
        SlidableAction(onPressed: (ctx) => Provider.of<BujoProvider>(ctx, listen: false).changeStatus(b.id, BulletStatus.completed), backgroundColor: Colors.green, foregroundColor: Colors.white, icon: Icons.check),
        SlidableAction(onPressed: (ctx) => Provider.of<BujoProvider>(ctx, listen: false).changeStatus(b.id, BulletStatus.cancelled), backgroundColor: Colors.grey, foregroundColor: Colors.white, icon: Icons.close),
      ],
    );
  }

  ActionPane _buildEndPane(Bullet b) {
    return ActionPane(
      motion: const ScrollMotion(),
      children: [
        SlidableAction(onPressed: (ctx) => _pickNewDate(ctx, Provider.of<BujoProvider>(ctx, listen: false), b), backgroundColor: Colors.blue, foregroundColor: Colors.white, icon: Icons.calendar_today),
        SlidableAction(onPressed: (ctx) => Provider.of<BujoProvider>(ctx, listen: false).deleteBullet(b.id), backgroundColor: Colors.red, foregroundColor: Colors.white, icon: Icons.delete),
      ],
    );
  }

  Future<void> _pickNewDate(BuildContext context, BujoProvider provider, Bullet b) async {
    final result = await showBujoDatePicker(context, initialDate: b.date ?? DateTime.now(), initialScope: b.scope);
    if (result != null) {
      if (result.date == null) provider.updateBulletFull(b.id, content: b.content, type: b.type, date: null, scope: BulletScope.none, collectionId: null);
      else provider.moveBullet(b, result.date!, result.scope);
    }
  }

  Widget _buildStripContent(Bullet bullet, {bool isDragging = false}) {
    bool isCancelled = bullet.status == BulletStatus.cancelled;
    bool isCompleted = bullet.status == BulletStatus.completed;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDragging ? null : () => _showEditDialog(context, bullet),
        child: Container(
          margin: const EdgeInsets.only(bottom: 2), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 【核心修复】Icon 增加点击事件
            GestureDetector(
              onTap: bullet.type == 'task' 
                  ? () => Provider.of<BujoProvider>(context, listen: false).toggleStatus(bullet.id)
                  : null,
              child: Container(
                color: Colors.transparent, 
                padding: const EdgeInsets.only(top: 2, right: 8, bottom: 2),
                child: Icon(_getIcon(bullet), size: 10, color: (bullet.type == 'task' && !bullet.isCompleted) ? Colors.black : Colors.grey),
              ),
            ),
            Expanded(child: Text(bullet.content, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, decoration: isCancelled ? TextDecoration.lineThrough : null, color: (isCompleted || isCancelled) ? Colors.grey : Colors.black87))),
          ]),
        ),
      ),
    );
  }

  IconData _getIcon(Bullet b) {
    if (b.type == 'task') {
      if (b.status == BulletStatus.completed) return Icons.close;
      if (b.status == BulletStatus.cancelled) return Icons.circle;
      return Icons.circle;
    }
    if (b.type == 'event') return Icons.radio_button_unchecked;
    if (b.type == 'note') return Icons.remove;
    return Icons.circle;
  }

  void _showEditDialog(BuildContext context, Bullet bullet) {
    final controller = TextEditingController(text: bullet.content);
    final provider = Provider.of<BujoProvider>(context, listen: false);
    String selectedType = bullet.type;
    DateTime? selectedDate = bullet.date;
    BulletScope selectedScope = bullet.scope;
    String? selectedCollectionId = bullet.collectionId;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setState) {
      String collectionName = selectedCollectionId != null ? provider.collections.firstWhere((e) => e.id == selectedCollectionId, orElse: () => Collection(id:'', name:'未知')).name : "集子";
      String dateStr = "日期";
      if (selectedDate != null) {
        if (selectedScope == BulletScope.day) dateStr = DateFormat('MM-dd').format(selectedDate!);
        else if (selectedScope == BulletScope.week) dateStr = "第${calculateWeekNumber(selectedDate!)}周";
        else if (selectedScope == BulletScope.month) dateStr = "${selectedDate!.month}月";
        else if (selectedScope == BulletScope.year) dateStr = "${selectedDate!.year}年";
      }

      return AlertDialog(
        title: const Text("编辑任务"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
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
        ]),
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
    }));
  }

  Widget _buildStyledOption({required IconData icon, required String label, bool isHighLighted = false, required VoidCallback onTap}) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8), decoration: BoxDecoration(color: isHighLighted ? Colors.blue : Colors.grey[100], borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 16, color: isHighLighted ? Colors.white : Colors.grey), const SizedBox(width: 4), Flexible(child: Text(label, style: TextStyle(fontSize: 12, color: isHighLighted ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis))])));
  }
  Widget _buildTypeOption(String type, IconData icon, String current, Function(String) onTap) {
    return GestureDetector(onTap: () => onTap(type), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: type == current ? Colors.blue.withValues(alpha: 0.1) : Colors.transparent, borderRadius: BorderRadius.circular(4), border: Border.all(color: type == current ? Colors.blue : Colors.transparent)), child: Icon(icon, color: type == current ? Colors.blue : Colors.grey, size: 18)));
  }
}