import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bujo_provider.dart';
import '../models/bullet.dart';
import '../models/collection.dart';
import '../widgets/bujo_drawer.dart';
import '../widgets/bujo_date_picker.dart';
import '../widgets/bullet_edit_dialog.dart';
import '../widgets/bujo_search_delegate.dart';
import '../widgets/draggable_bullet_item.dart';
import '../widgets/insertion_bar.dart'; // 使用插入条
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
      child: Column(children: [
        _buildMonthlyPool(monthDate),
        Expanded(
          child: Container(
            color: Colors.white,
            child: RefreshIndicator(
              onRefresh: () async { await showSearch(context: context, delegate: BujoSearchDelegate()); },
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: DateTime(monthDate.year, monthDate.month + 1, 0).day,
                itemBuilder: (context, i) {
                  final currentDate = DateTime(monthDate.year, monthDate.month, i + 1);
                  return _buildDayRow(currentDate);
                },
              ),
            ),
          )
        )
      ]),
    );
  }

  Widget _buildMonthlyPool(DateTime monthDate) {
    // 顶部池子：使用 InsertionBar 穿插
    return Consumer<BujoProvider>(builder: (context, provider, _) {
      final monthlyBullets = provider.getBulletsByScope(monthDate, BulletScope.month);
      
      List<Widget> children = [];
      children.add(InsertionBar(prevBulletId: null, targetDate: monthDate, targetScope: BulletScope.month, targetCollectionId: null));
      for (var b in monthlyBullets) {
        children.add(_buildDraggableItem(context, provider, b, isPool: true));
        children.add(InsertionBar(prevBulletId: b.id, targetDate: monthDate, targetScope: BulletScope.month, targetCollectionId: null));
      }

      if (monthlyBullets.isEmpty) {
         // 最小高度用于接收
         return Container(
           height: 20, 
           width: double.infinity, 
           color: const Color(0xFFF5F9FF),
           child: children.first, // 只放一个顶部的 InsertionBar 即可接收拖拽
         );
      }

      return Container(
        width: double.infinity, 
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFF5F9FF), border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
    });
  }

  Widget _buildDayRow(DateTime date) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final weekdayChar = _weekdays[date.weekday - 1]; 

    return Container(
      decoration: BoxDecoration(color: isToday ? const Color(0xFFFFFDE7) : Colors.transparent, border: Border(bottom: BorderSide(color: Colors.grey[100]!, width: 0.5))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () { Provider.of<BujoProvider>(context, listen: false).setFocusDate(date); widget.onJumpToDay(); },
          child: Container(width: 50, padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), alignment: Alignment.topCenter, decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[50]!))), child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [Text("${date.day}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isToday ? Colors.blue : Colors.black87)), const SizedBox(width: 2), Text(weekdayChar, style: TextStyle(fontSize: 10, color: isToday ? Colors.blue : Colors.grey))])),
        ),
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), child: Consumer<BujoProvider>(builder: (ctx, provider, _) {
          final dayBullets = provider.getBulletsByScope(date, BulletScope.day);
          
          // 【核心修改】使用 InsertionBar 穿插逻辑，解决底部太宽问题
          List<Widget> children = [];
          children.add(InsertionBar(prevBulletId: null, targetDate: date, targetScope: BulletScope.day, targetCollectionId: null));
          for (var b in dayBullets) {
            children.add(_buildDraggableItem(ctx, provider, b));
            children.add(InsertionBar(prevBulletId: b.id, targetDate: date, targetScope: BulletScope.day, targetCollectionId: null));
          }

          return Column(children: children);
        }))),
      ]),
    );
  }

  Widget _buildDraggableItem(BuildContext context, BujoProvider provider, Bullet bullet, {bool isPool = false}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final width = isPool ? screenWidth * 0.8 : screenWidth - 70;
    int depth = provider.getBulletDepth(bullet);
    double indent = depth * 16.0;

    Widget slidableItem = Slidable(key: ValueKey(bullet.id), groupTag: isPool ? 'monthly_pool' : 'monthly_list', startActionPane: _buildStartPane(context, provider, bullet), endActionPane: _buildEndPane(context, provider, bullet), child: _buildStripContent(context, provider, bullet, indent: indent));

    return DraggableBulletItem(bullet: bullet, child: slidableItem);
  }

  ActionPane _buildStartPane(BuildContext context, BujoProvider provider, Bullet b) { return ActionPane(motion: const ScrollMotion(), children: [SlidableAction(onPressed: (ctx) => Provider.of<BujoProvider>(ctx, listen: false).changeStatus(b.id, BulletStatus.completed), backgroundColor: Colors.green, foregroundColor: Colors.white, icon: Icons.check), SlidableAction(onPressed: (ctx) => Provider.of<BujoProvider>(ctx, listen: false).changeStatus(b.id, BulletStatus.cancelled), backgroundColor: Colors.grey, foregroundColor: Colors.white, icon: Icons.close)]); }
  ActionPane _buildEndPane(BuildContext context, BujoProvider provider, Bullet b) { return ActionPane(motion: const ScrollMotion(), children: [SlidableAction(onPressed: (ctx) => _pickNewDate(ctx, Provider.of<BujoProvider>(ctx, listen: false), b), backgroundColor: Colors.blue, foregroundColor: Colors.white, icon: Icons.calendar_today), SlidableAction(onPressed: (ctx) => Provider.of<BujoProvider>(ctx, listen: false).deleteBullet(b.id), backgroundColor: Colors.red, foregroundColor: Colors.white, icon: Icons.delete)]); }
  Future<void> _pickNewDate(BuildContext context, BujoProvider provider, Bullet b) async { final result = await showBujoDatePicker(context, initialDate: b.date ?? DateTime.now(), initialScope: b.scope); if (result != null) { if (result.date == null) provider.updateBulletFull(b.id, content: b.content, type: b.type, date: null, scope: BulletScope.none, collectionId: null); else provider.moveBullet(b, result.date!, result.scope); } }
  Widget _buildStripContent(BuildContext context, BujoProvider provider, Bullet bullet, {bool isDragging = false, double indent = 0}) { bool isCancelled = bullet.status == BulletStatus.cancelled; bool isCompleted = bullet.status == BulletStatus.completed; return Material(color: Colors.transparent, child: InkWell(onTap: isDragging ? null : () => showBulletEditDialog(context, bullet), child: Container(margin: const EdgeInsets.only(bottom: 2), padding: EdgeInsets.only(left: 4 + indent, right: 4, top: 4, bottom: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [GestureDetector(onTap: bullet.type == 'task' ? () => Provider.of<BujoProvider>(context, listen: false).toggleStatus(bullet.id) : null, child: Container(padding: const EdgeInsets.only(top: 2, right: 8, bottom: 2), color: Colors.transparent, child: Icon(_getIcon(bullet), size: 10, color: (bullet.type == 'task' && !isCompleted && !isCancelled) ? Colors.black : Colors.grey))), Expanded(child: Text(bullet.content, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, decoration: isCancelled ? TextDecoration.lineThrough : null, color: (isCompleted || isCancelled) ? Colors.grey : Colors.black87)))])))); }
  IconData _getIcon(Bullet b) { if (b.type == 'task') { if (b.status == BulletStatus.completed) return Icons.close; if (b.status == BulletStatus.cancelled) return Icons.circle; return Icons.circle; } if (b.type == 'event') return Icons.radio_button_unchecked; if (b.type == 'note') return Icons.remove; return Icons.circle; }
}