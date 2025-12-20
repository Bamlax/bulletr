import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/bullet.dart';
import '../providers/bujo_provider.dart';
import 'bullet_edit_dialog.dart';
import 'bujo_date_picker.dart';
import 'draggable_bullet_item.dart';
import 'insertion_bar.dart'; // 只需要这个

class BulletListBuilder extends StatelessWidget {
  final List<Bullet> bullets;
  final String listTag;
  final DateTime? date; 
  final BulletScope scope;
  final String? collectionId;

  const BulletListBuilder({
    super.key,
    required this.bullets,
    required this.listTag,
    this.date,
    this.scope = BulletScope.day,
    this.collectionId,
  });

  @override
  Widget build(BuildContext context) {
    return SlidableAutoCloseBehavior(
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                // 列表逻辑：2n 是插入条，2n+1 是任务
                if (index.isEven) {
                  final bulletIndex = index ~/ 2;
                  String? prevId;
                  if (bulletIndex > 0) {
                    prevId = bullets[bulletIndex - 1].id;
                  }
                  return InsertionBar(
                    prevBulletId: prevId,
                    targetDate: date,
                    targetScope: scope,
                    targetCollectionId: collectionId,
                  );
                } else {
                  final bulletIndex = index ~/ 2;
                  final b = bullets[bulletIndex];
                  return _buildListItem(context, b, index);
                }
              },
              // 数量 = 任务数 * 2 + 1 (最后一条后面也有 InsertionBar)
              childCount: bullets.length * 2 + 1,
            ),
          ),
          
          // 填充剩余空白区域，允许拖拽到这里自动追加到末尾
          SliverFillRemaining(
            hasScrollBody: false,
            child: DragTarget<Bullet>(
              onWillAccept: (data) => data != null,
              onAccept: (bullet) {
                // 插到最后一个任务后面
                String? lastId = bullets.isNotEmpty ? bullets.last.id : null;
                Provider.of<BujoProvider>(context, listen: false).insertBulletAfter(
                  activeId: bullet.id,
                  prevId: lastId,
                  targetDate: date,
                  targetScope: scope,
                  targetCollectionId: collectionId
                );
              },
              builder: (ctx, candidates, rejected) {
                 return Container(color: Colors.transparent);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(BuildContext context, Bullet b, int index) {
    final provider = Provider.of<BujoProvider>(context, listen: false);
    int depth = provider.getBulletDepth(b);
    double indent = depth * 24.0;

    Widget slidableItem = Slidable(
      key: ValueKey(b.id),
      groupTag: listTag,
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(onPressed: (ctx) => provider.changeStatus(b.id, BulletStatus.completed), backgroundColor: Colors.green, foregroundColor: Colors.white, icon: Icons.check),
          SlidableAction(onPressed: (ctx) => provider.changeStatus(b.id, BulletStatus.cancelled), backgroundColor: Colors.grey, foregroundColor: Colors.white, icon: Icons.close),
        ],
      ),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(onPressed: (ctx) => _pickNewDate(ctx, provider, b), backgroundColor: Colors.blue, foregroundColor: Colors.white, icon: Icons.calendar_today),
          SlidableAction(onPressed: (ctx) => provider.deleteBullet(b.id), backgroundColor: Colors.red, foregroundColor: Colors.white, icon: Icons.delete),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showBulletEditDialog(context, b),
          splashColor: Colors.blue.withValues(alpha: 0.1),
          highlightColor: Colors.grey.withValues(alpha: 0.1),
          child: Container(
            padding: EdgeInsets.only(left: 16 + indent, right: 16, top: 0, bottom: 0),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index, // 注意：这里的 index 仅仅为了 Widget 结构，实际排序逻辑已由 InsertionBar 接管
                  enabled: false, // 禁用自带的排序监听，防止冲突
                  child: GestureDetector(
                    onTap: b.type == 'task' ? () => provider.toggleStatus(b.id) : null,
                    child: Container(
                      color: Colors.transparent,
                      padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                      child: Icon(
                        _getIcon(b),
                        size: 14,
                        color: (b.type == 'task' && !b.isCompleted && !b.isCancelled) 
                            ? Colors.black 
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: LongPressDraggable<Bullet>(
                    data: b,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Container(
                        // 宽度设为屏幕宽的一定比例
                        width: MediaQuery.of(context).size.width * 0.7,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          b.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                            height: 1.2,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _buildText(b),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _buildText(b),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return DraggableBulletItem(
      bullet: b,
      child: slidableItem,
    );
  }

  Widget _buildText(Bullet b) {
    return Text(
      b.content,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        decoration: b.status == BulletStatus.cancelled ? TextDecoration.lineThrough : null,
        color: (b.status != BulletStatus.open) ? Colors.grey : Colors.black87,
        fontSize: 15,
        height: 1.2,
      ),
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