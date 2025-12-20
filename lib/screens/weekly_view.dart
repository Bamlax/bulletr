import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../providers/bujo_provider.dart';
import '../models/bullet.dart';
import '../models/collection.dart';
import '../widgets/bujo_drawer.dart';
import '../widgets/bujo_date_picker.dart';
import '../widgets/bullet_edit_dialog.dart';
import '../widgets/bujo_search_delegate.dart';
import '../widgets/draggable_bullet_item.dart';
import '../widgets/insertion_bar.dart';

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
      child: Column(
        children: [
          _buildWeeklyPool(weekStart),
          Expanded(
            child: Container(
              color: Colors.white,
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
        ],
      ),
    );
  }

  Widget _buildWeeklyPool(DateTime weekStart) {
    return Consumer<BujoProvider>(
      builder: (context, provider, _) {
        final weeklyBullets = provider.getBulletsByScope(weekStart, BulletScope.week);
        
        List<Widget> children = [];
        
        // 顶部插入条
        children.add(InsertionBar(
          prevBulletId: null,
          targetDate: weekStart,
          targetScope: BulletScope.week,
          targetCollectionId: null,
        ));

        // 任务 + 插入条
        for (var b in weeklyBullets) {
          children.add(_buildDraggableItem(context, provider, b, isPool: true));
          children.add(InsertionBar(
            prevBulletId: b.id,
            targetDate: weekStart,
            targetScope: BulletScope.week,
            targetCollectionId: null,
          ));
        }

        // 如果为空，只显示一个极小的高度
        if (weeklyBullets.isEmpty) {
           return Container(height: 1, width: double.infinity, color: const Color(0xFFEEEEEE));
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F9FF),
            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        );
      },
    );
  }

  Widget _buildDayDropTarget(DateTime date) {
    final isToday = DateFormat('yyyyMMdd').format(date) == DateFormat('yyyyMMdd').format(DateTime.now());
    final weekdayChar = _weekdays[date.weekday - 1];
    final dayNum = date.day.toString();

    return Container(
      decoration: BoxDecoration(
        color: isToday ? const Color(0xFFFFFDE7) : Colors.transparent,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧日期头
          InkWell(
            onTap: () {
              Provider.of<BujoProvider>(context, listen: false).setFocusDate(date);
              widget.onJumpToDay();
            },
            child: Container(
              width: 60,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Colors.grey[100]!)),
              ),
              child: Column(children: [
                Text(dayNum, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isToday ? Colors.blue : Colors.black87)),
                Text(weekdayChar, style: TextStyle(fontSize: 12, color: isToday ? Colors.blue : Colors.grey)),
              ]),
            ),
          ),
          
          // 右侧任务列表
          Expanded(
            // 移除垂直 padding，紧凑布局
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Consumer<BujoProvider>(
                builder: (ctx, provider, _) {
                  final dayBullets = provider.getBulletsByScope(date, BulletScope.day);
                  
                  List<Widget> children = [];
                  
                  // 1. 顶部插入条 (prevId: null)
                  children.add(InsertionBar(
                    prevBulletId: null,
                    targetDate: date,
                    targetScope: BulletScope.day,
                    targetCollectionId: null,
                  ));

                  // 2. 任务 + 插入条
                  for (var b in dayBullets) {
                    children.add(_buildDraggableItem(ctx, provider, b));
                    children.add(InsertionBar(
                      prevBulletId: b.id,
                      targetDate: date,
                      targetScope: BulletScope.day,
                      targetCollectionId: null,
                    ));
                  }
                  
                  return Column(children: children);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableItem(BuildContext context, BujoProvider provider, Bullet bullet, {bool isPool = false}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final width = isPool ? screenWidth * 0.8 : screenWidth - 80;
    
    int depth = provider.getBulletDepth(bullet);
    double indent = depth * 16.0;

    Widget slidableItem = Slidable(
      key: ValueKey(bullet.id),
      groupTag: isPool ? 'weekly_pool' : 'weekly_list',
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(onPressed: (ctx) => provider.changeStatus(bullet.id, BulletStatus.completed), backgroundColor: Colors.green, foregroundColor: Colors.white, icon: Icons.check),
          SlidableAction(onPressed: (ctx) => provider.changeStatus(bullet.id, BulletStatus.cancelled), backgroundColor: Colors.grey, foregroundColor: Colors.white, icon: Icons.close),
        ],
      ),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(onPressed: (ctx) => _pickNewDate(ctx, provider, bullet), backgroundColor: Colors.blue, foregroundColor: Colors.white, icon: Icons.calendar_today),
          SlidableAction(onPressed: (ctx) => provider.deleteBullet(bullet.id), backgroundColor: Colors.red, foregroundColor: Colors.white, icon: Icons.delete),
        ],
      ),
      child: _buildStripContent(context, provider, bullet, indent: indent),
    );

    return DraggableBulletItem(
      bullet: bullet,
      child: LongPressDraggable<Bullet>(
        data: bullet,
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            width: width,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Icon(_getIcon(bullet), size: 10, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(child: Text(bullet.content, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: Colors.black87, decoration: TextDecoration.none))),
              ],
            )
          )
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: slidableItem),
        child: slidableItem,
      ),
    );
  }

  Future<void> _pickNewDate(BuildContext context, BujoProvider provider, Bullet b) async {
    final result = await showBujoDatePicker(context, initialDate: b.date ?? DateTime.now(), initialScope: b.scope);
    if (result != null) {
      if (result.date == null) provider.updateBulletFull(b.id, content: b.content, type: b.type, date: null, scope: BulletScope.none, collectionId: null);
      else provider.moveBullet(b, result.date!, result.scope);
    }
  }

  Widget _buildStripContent(BuildContext context, BujoProvider provider, Bullet bullet, {bool isDragging = false, double indent = 0}) {
    bool isCancelled = bullet.status == BulletStatus.cancelled;
    bool isCompleted = bullet.status == BulletStatus.completed;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDragging ? null : () => showBulletEditDialog(context, bullet),
        child: Container(
          margin: const EdgeInsets.only(bottom: 2), 
          padding: EdgeInsets.only(left: 4 + indent, right: 4, top: 4, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: bullet.type == 'task' ? () => Provider.of<BujoProvider>(context, listen: false).toggleStatus(bullet.id) : null,
                child: Container(
                  padding: const EdgeInsets.only(top: 2, right: 8, bottom: 2),
                  color: Colors.transparent,
                  child: Icon(
                    _getIcon(bullet),
                    size: 10,
                    color: (bullet.type == 'task' && !isCompleted && !isCancelled) ? Colors.black : Colors.grey,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  bullet.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                    color: (isCompleted || isCancelled) ? Colors.grey : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
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