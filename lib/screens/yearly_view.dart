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
import '../widgets/insertion_bar.dart';
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
          child: Text(
            "$year年",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _displayedYear = DateTime(_anchorDate.year + (index - _anchorIndex), 1, 1);
          });
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
      child: Column(
        children: [
          _buildYearlyPool(yearDate),
          Expanded(
            child: Container(
              color: Colors.white,
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearlyPool(DateTime yearDate) {
    return DragTarget<Bullet>(
      onAcceptWithDetails: (details) {
        Provider.of<BujoProvider>(context, listen: false)
            .moveBullet(details.data, yearDate, BulletScope.year);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Consumer<BujoProvider>(
          builder: (context, provider, _) {
            final yearlyBullets = provider.getBulletsByScope(yearDate, BulletScope.year);
            
            if (yearlyBullets.isEmpty && !isHovering) {
              return Container(height: 1, width: double.infinity, color: const Color(0xFFEEEEEE));
            }

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isHovering ? Colors.blue.withValues(alpha: 0.1) : const Color(0xFFF5F9FF),
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (yearlyBullets.isNotEmpty)
                    ...yearlyBullets.map((b) => _buildDraggableItem(context, provider, b, isPool: true)),
                  
                  if (isHovering)
                    const Center(child: Text("放回到年度目标", style: TextStyle(color: Colors.blue, fontSize: 12))),
                  
                  InsertionBar(prevBulletId: yearlyBullets.isNotEmpty ? yearlyBullets.last.id : null, targetDate: yearDate, targetScope: BulletScope.year, targetCollectionId: null),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMonthDropTarget(DateTime monthDate) {
    final now = DateTime.now();
    final isCurrentMonth = monthDate.year == now.year && monthDate.month == now.month;
    final monthNum = monthDate.month.toString();

    return DragTarget<Bullet>(
      onAcceptWithDetails: (details) {
        Provider.of<BujoProvider>(context, listen: false)
            .moveBullet(details.data, monthDate, BulletScope.month);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: isHovering 
                ? Colors.blue.withValues(alpha: 0.1) 
                : (isCurrentMonth ? const Color(0xFFFFFDE7) : Colors.transparent),
            border: Border(bottom: BorderSide(color: Colors.grey[100]!, width: 0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () {
                  Provider.of<BujoProvider>(context, listen: false).setFocusDate(monthDate);
                  widget.onJumpToMonth();
                },
                child: Container(
                  width: 50,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  alignment: Alignment.topCenter,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Colors.grey[50]!)),
                  ),
                  child: Text(
                    "$monthNum月",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isCurrentMonth ? Colors.blue : Colors.black87,
                    ),
                  ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Consumer<BujoProvider>(
                    builder: (ctx, provider, _) {
                      final monthlyBullets = provider.getBulletsByScope(monthDate, BulletScope.month);
                      
                      List<Widget> children = [];
                      children.add(InsertionBar(prevBulletId: null, targetDate: monthDate, targetScope: BulletScope.month, targetCollectionId: null));
                      for (var b in monthlyBullets) {
                        children.add(_buildDraggableItem(ctx, provider, b));
                        children.add(InsertionBar(prevBulletId: b.id, targetDate: monthDate, targetScope: BulletScope.month, targetCollectionId: null));
                      }
                      
                      return Column(children: children);
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

  // ... (保留辅助方法: _buildDraggableItem, _buildStartPane, _buildEndPane, _pickNewDate, _buildStripContent, _getIcon - 代码完全一致)
  Widget _buildDraggableItem(BuildContext context, BujoProvider provider, Bullet bullet, {bool isPool = false}) { final screenWidth = MediaQuery.of(context).size.width; final width = isPool ? screenWidth * 0.8 : screenWidth - 70; int depth = provider.getBulletDepth(bullet); double indent = depth * 16.0; Widget slidableItem = Slidable(key: ValueKey(bullet.id), groupTag: isPool ? 'yearly_pool' : 'yearly_list', startActionPane: (bullet.type == 'task') ? _buildStartPane(context, provider, bullet) : null, endActionPane: _buildEndPane(context, provider, bullet), child: _buildStripContent(context, provider, bullet, indent: indent)); return DraggableBulletItem(bullet: bullet, child: slidableItem); }
  ActionPane _buildStartPane(BuildContext context, BujoProvider provider, Bullet b) { return ActionPane(motion: const ScrollMotion(), children: [SlidableAction(onPressed: (ctx) => Provider.of<BujoProvider>(ctx, listen: false).changeStatus(b.id, BulletStatus.completed), backgroundColor: Colors.green, foregroundColor: Colors.white, icon: Icons.check), SlidableAction(onPressed: (ctx) => Provider.of<BujoProvider>(ctx, listen: false).changeStatus(b.id, BulletStatus.cancelled), backgroundColor: Colors.grey, foregroundColor: Colors.white, icon: Icons.close)]); }
  ActionPane _buildEndPane(BuildContext context, BujoProvider provider, Bullet b) { return ActionPane(motion: const ScrollMotion(), children: [SlidableAction(onPressed: (ctx) => _pickNewDate(ctx, Provider.of<BujoProvider>(ctx, listen: false), b), backgroundColor: Colors.blue, foregroundColor: Colors.white, icon: Icons.calendar_today), SlidableAction(onPressed: (ctx) => Provider.of<BujoProvider>(ctx, listen: false).deleteBullet(b.id), backgroundColor: Colors.red, foregroundColor: Colors.white, icon: Icons.delete)]); }
  Future<void> _pickNewDate(BuildContext context, BujoProvider provider, Bullet b) async { final result = await showBujoDatePicker(context, initialDate: b.date ?? DateTime.now(), initialScope: b.scope); if (result != null) { if (result.date == null) provider.updateBulletFull(b.id, content: b.content, type: b.type, date: null, scope: BulletScope.none, collectionId: null); else provider.moveBullet(b, result.date!, result.scope); } }
  Widget _buildStripContent(BuildContext context, BujoProvider provider, Bullet bullet, {bool isDragging = false, double indent = 0}) { bool isCancelled = bullet.status == BulletStatus.cancelled; bool isCompleted = bullet.status == BulletStatus.completed; return Material(color: Colors.transparent, child: InkWell(onTap: isDragging ? null : () => showBulletEditDialog(context, bullet), child: Container(margin: const EdgeInsets.only(bottom: 2), padding: EdgeInsets.only(left: 4 + indent, right: 4, top: 4, bottom: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [GestureDetector(onTap: bullet.type == 'task' ? () => Provider.of<BujoProvider>(context, listen: false).toggleStatus(bullet.id) : null, child: Container(padding: const EdgeInsets.only(top: 2, right: 8, bottom: 2), color: Colors.transparent, child: Icon(_getIcon(bullet), size: 10, color: (bullet.type == 'task' && !isCompleted && !isCancelled) ? Colors.black : Colors.grey))), Expanded(child: Text(bullet.content, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, decoration: isCancelled ? TextDecoration.lineThrough : null, color: (isCompleted || isCancelled) ? Colors.grey : Colors.black87)))])))); }
  IconData _getIcon(Bullet b) { if (b.type == 'task') { if (b.status == BulletStatus.completed) return Icons.close; if (b.status == BulletStatus.cancelled) return Icons.circle; return Icons.circle; } if (b.type == 'event') return Icons.radio_button_unchecked; if (b.type == 'note') return Icons.remove; return Icons.circle; }
}