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
          child: Text(titleString, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
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
        
        // 【核心修改】下拉搜索
        return RefreshIndicator(
          onRefresh: () async {
            await showSearch(context: context, delegate: BujoSearchDelegate());
          },
          child: bullets.isEmpty 
            ? ListView(children: const [SizedBox(height: 300, child: Center(child: Text("点击 + 添加计划", style: TextStyle(color: Colors.grey, fontSize: 20))))])
            : SlidableAutoCloseBehavior(
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
                        startActionPane: ActionPane(
                          motion: const ScrollMotion(),
                          children: [
                            SlidableAction(
                              onPressed: (ctx) => provider.changeStatus(b.id, BulletStatus.completed),
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              icon: Icons.check,
                            ),
                            SlidableAction(
                              onPressed: (ctx) => provider.changeStatus(b.id, BulletStatus.cancelled),
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                              icon: Icons.close,
                            ),
                          ],
                        ),
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
    bool isCancelled = b.status == BulletStatus.cancelled;
    bool isCompleted = b.status == BulletStatus.completed;
    
    return Material(
      color: Colors.transparent, 
      child: InkWell(
        // 【修改】调用公共的编辑框
        onTap: () => showBulletEditDialog(context, b),
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
                    color: (b.type == 'task' && !isCompleted && !isCancelled) ? Colors.black : Colors.grey,
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
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                    color: (isCompleted || isCancelled) ? Colors.grey : Colors.black87,
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