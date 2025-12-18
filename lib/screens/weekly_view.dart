import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../providers/bujo_provider.dart';
import '../models/bullet.dart';
import '../models/collection.dart';
import '../widgets/bujo_drawer.dart';
import '../widgets/bujo_date_picker.dart';
import '../widgets/bullet_edit_dialog.dart'; // 【新增】
import '../widgets/bujo_search_delegate.dart'; // 【新增】

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
    final endOfWeek = _displayedWeekStart.add(const Duration(days: 6));
    final year = endOfWeek.year; 
    final weekNum = calculateWeekNumber(_displayedWeekStart);
    final rangeStr = "${DateFormat('MM.dd').format(_displayedWeekStart)} - ${DateFormat('MM.dd').format(endOfWeek)}";

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: GestureDetector(
          onLongPress: () {
            _pageController.animateToPage(
              _anchorIndex, 
              duration: const Duration(milliseconds: 300), 
              curve: Curves.easeInOut
            );
          },
          child: Column(children: [
            Text("$year年 第$weekNum周", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(rangeStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ),
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
    return SlidableAutoCloseBehavior(
      child: Column(children: [
        _buildWeeklyPool(weekStart),
        Expanded(
          child: Container(
            color: Colors.white,
            // 【新增】下拉搜索
            child: RefreshIndicator(
              onRefresh: () async {
                await showSearch(context: context, delegate: BujoSearchDelegate());
              },
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
        ),
      ]),
    );
  }

  Widget _buildWeeklyPool(DateTime weekStart) {
    return DragTarget<Bullet>(
      onAcceptWithDetails: (details) {
        Provider.of<BujoProvider>(context, listen: false).moveBullet(details.data, weekStart, BulletScope.week);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Consumer<BujoProvider>(builder: (context, provider, _) {
          final weeklyBullets = provider.getBulletsByScope(weekStart, BulletScope.week);
          if (weeklyBullets.isEmpty && !isHovering) return Container(height: 20, width: double.infinity, color: Colors.transparent);
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: isHovering ? Colors.blue.withValues(alpha: 0.1) : const Color(0xFFF5F9FF), border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (weeklyBullets.isNotEmpty) ...weeklyBullets.map((b) => _buildDraggablePoolStrip(b)),
              if (isHovering) const Center(child: Text("放回到本周任务", style: TextStyle(color: Colors.blue, fontSize: 12))),
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
        groupTag: 'weekly_pool',
        startActionPane: _buildStartPane(bullet),
        endActionPane: _buildEndPane(bullet),
        child: _buildStripContent(bullet),
      ),
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
          decoration: BoxDecoration(color: isHovering ? Colors.blue.withValues(alpha: 0.1) : (isToday ? const Color(0xFFFFFDE7) : Colors.transparent), border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              onTap: () { Provider.of<BujoProvider>(context, listen: false).setFocusDate(date); widget.onJumpToDay(); },
              child: Container(width: 60, padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[100]!))), child: Column(children: [Text(dayNum, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isToday ? Colors.blue : Colors.black87)), Text(weekdayChar, style: TextStyle(fontSize: 12, color: isToday ? Colors.blue : Colors.grey))])),
            ),
            Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8), child: Consumer<BujoProvider>(builder: (ctx, provider, _) {
              final dayBullets = provider.getBulletsByScope(date, BulletScope.day);
              if (dayBullets.isEmpty) return const SizedBox(height: 36);
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
      feedback: Material(color: Colors.transparent, elevation: 4, child: Container(width: screenWidth - 80, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)), child: _buildStripContent(bullet, isDragging: true))),
      childWhenDragging: Opacity(opacity: 0.3, child: _buildStripContent(bullet)),
      child: Slidable(
        key: ValueKey(bullet.id),
        groupTag: 'weekly_list',
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
        // 【核心修改】调用公共编辑框
        onTap: isDragging ? null : () => showBulletEditDialog(context, bullet),
        child: Container(
          margin: const EdgeInsets.only(bottom: 2), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: bullet.type == 'task' ? () => Provider.of<BujoProvider>(context, listen: false).toggleStatus(bullet.id) : null,
              child: Container(
                color: Colors.transparent, 
                padding: const EdgeInsets.only(top: 2, right: 8, bottom: 2),
                child: Icon(_getIcon(bullet), size: 14, color: (bullet.type == 'task' && !isCompleted && !isCancelled) ? Colors.black : Colors.grey),
              ),
            ),
            Expanded(child: Text(bullet.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, height: 1.2, decoration: isCancelled ? TextDecoration.lineThrough : null, color: (isCompleted || isCancelled) ? Colors.grey : Colors.black87))),
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
}