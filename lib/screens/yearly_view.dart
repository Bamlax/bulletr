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

class YearlyView extends StatefulWidget {
  final VoidCallback onJumpToMonth;
  const YearlyView({super.key, required this.onJumpToMonth});
  @override
  State<YearlyView> createState() => _YearlyViewState();
}

class _YearlyViewState extends State<YearlyView> {
  late PageController _pageController;
  late DateTime _displayedYear;
  final int _anchorIndex = 1000;
  final DateTime _anchorDate = DateTime(DateTime.now().year, 1, 1);

  @override
  void initState() {
    super.initState();
    final rawFocusDate = Provider.of<BujoProvider>(context, listen: false).focusDate;
    _displayedYear = DateTime(rawFocusDate.year, 1, 1);
    int yearDiff = _displayedYear.year - _anchorDate.year;
    _pageController = PageController(initialPage: _anchorIndex + yearDiff);
  }

  @override
  Widget build(BuildContext context) {
    final year = _displayedYear.year;
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
          child: Text("$year年", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        centerTitle: true, backgroundColor: Colors.white, elevation: 0, bottom: const PreferredSize(preferredSize: Size.fromHeight(1.0), child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)))),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() { _displayedYear = DateTime(_anchorDate.year + (index - _anchorIndex), 1, 1); });
          Provider.of<BujoProvider>(context, listen: false).setFocusDate(_displayedYear);
        },
        itemBuilder: (context, index) {
          final yearDate = DateTime(_anchorDate.year + (index - _anchorIndex), 1, 1);
          return _buildSingleYearPage(yearDate);
        },
      ),
    );
  }

  Widget _buildSingleYearPage(DateTime yearDate) {
    return SlidableAutoCloseBehavior(
      child: Column(children: [
        _buildYearlyPool(yearDate),
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
                itemCount: 12,
                itemBuilder: (context, i) {
                  final monthDate = DateTime(yearDate.year, i + 1, 1);
                  return _buildMonthDropTarget(monthDate);
                },
              ),
            )
          )
        )
      ]),
    );
  }

  Widget _buildYearlyPool(DateTime yearDate) {
    return DragTarget<Bullet>(
      onAcceptWithDetails: (details) {
        Provider.of<BujoProvider>(context, listen: false).moveBullet(details.data, yearDate, BulletScope.year);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Consumer<BujoProvider>(builder: (context, provider, _) {
          final yearlyBullets = provider.getBulletsByScope(yearDate, BulletScope.year);
          if (yearlyBullets.isEmpty && !isHovering) return Container(height: 20, width: double.infinity, color: Colors.transparent);
          return Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: isHovering ? Colors.blue.withValues(alpha: 0.1) : const Color(0xFFF5F9FF), border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (yearlyBullets.isNotEmpty) ...yearlyBullets.map((b) => _buildDraggablePoolStrip(b)),
              if (isHovering) const Center(child: Text("放回到年度目标", style: TextStyle(color: Colors.blue, fontSize: 12))),
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
        groupTag: 'yearly_pool',
        startActionPane: _buildStartPane(bullet),
        endActionPane: _buildEndPane(bullet),
        child: _buildStripContent(bullet),
      ),
    );
  }

  Widget _buildMonthDropTarget(DateTime monthDate) {
    final now = DateTime.now();
    final isCurrentMonth = monthDate.year == now.year && monthDate.month == now.month;
    final monthNum = monthDate.month.toString();

    return DragTarget<Bullet>(
      onAcceptWithDetails: (details) {
        Provider.of<BujoProvider>(context, listen: false).moveBullet(details.data, monthDate, BulletScope.month);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(color: isHovering ? Colors.blue.withValues(alpha: 0.1) : (isCurrentMonth ? const Color(0xFFFFFDE7) : Colors.transparent), border: Border(bottom: BorderSide(color: Colors.grey[100]!, width: 1))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              onTap: () { Provider.of<BujoProvider>(context, listen: false).setFocusDate(monthDate); widget.onJumpToMonth(); },
              child: Container(width: 50, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4), alignment: Alignment.topCenter, decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[50]!))), child: Text("$monthNum月", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isCurrentMonth ? Colors.blue : Colors.black87))),
            ),
            Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), child: Consumer<BujoProvider>(builder: (ctx, provider, _) {
              final monthlyBullets = provider.getBulletsByScope(monthDate, BulletScope.month);
              if (monthlyBullets.isEmpty) return const SizedBox(height: 36);
              return Column(children: monthlyBullets.map((b) => _buildDraggableStrip(b)).toList());
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
        groupTag: 'yearly_list',
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