import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bujo_provider.dart';
import '../models/bullet.dart';
import '../models/collection.dart';
import '../widgets/bujo_drawer.dart';
import '../widgets/bujo_date_picker.dart';
import '../widgets/bullet_edit_dialog.dart'; // 【新增】
import '../widgets/bujo_search_delegate.dart'; // 【新增】
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
      child: Column(children: [
        _buildMonthlyPool(monthDate),
        Expanded(
          child: Container(
            color: Colors.white,
            // 【新增】下拉搜索
            child: RefreshIndicator(
              onRefresh: () async {
                await showSearch(context: context, delegate: BujoSearchDelegate());
              },
              child: _buildMonthList(monthDate)
            )
          )
        )
      ]),
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
      feedback: Material(color: Colors.transparent, elevation: 6, child: Container(width: screenWidth * 0.8, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)), child: _buildStripContent(bullet, isDragging: true))),
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
        // 【核心修改】调用公共编辑框
        onTap: isDragging ? null : () => showBulletEditDialog(context, bullet),
        child: Container(
          margin: const EdgeInsets.only(bottom: 2), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: bullet.type == 'task' ? () => Provider.of<BujoProvider>(context, listen: false).toggleStatus(bullet.id) : null,
              child: Container(padding: const EdgeInsets.only(top: 2, right: 8, bottom: 2), color: Colors.transparent, child: Icon(_getIcon(bullet), size: 10, color: (bullet.type == 'task' && !isCompleted && !isCancelled) ? Colors.black : Colors.grey)),
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
}