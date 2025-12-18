import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../providers/bujo_provider.dart';
import '../models/bullet.dart';
import '../models/collection.dart';
import '../widgets/bujo_date_picker.dart';
import '../widgets/bullet_edit_dialog.dart'; // 【新增】
import '../widgets/bujo_search_delegate.dart'; // 【新增】

class CollectionView extends StatelessWidget {
  final String title;
  final String? collectionId;

  const CollectionView({super.key, required this.title, required this.collectionId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1.0), child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE))),
        actions: collectionId != null ? [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: Colors.black),
            onSelected: (value) {
              if (value == 'rename') _showRenameDialog(context);
              else if (value == 'delete') _showDeleteCollectionDialog(context);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'rename', child: Text("重命名")),
              const PopupMenuItem(value: 'delete', child: Text("删除集子", style: TextStyle(color: Colors.red))),
            ],
          )
        ] : null,
      ),
      body: Consumer<BujoProvider>(
        builder: (context, provider, _) {
          final bullets = collectionId == null ? provider.getInboxBullets() : provider.getCollectionBullets(collectionId!);
          if (bullets.isEmpty) return Center(child: Text("没有内容", style: TextStyle(color: Colors.grey[300])));

          return SlidableAutoCloseBehavior(
            // 【新增】下拉搜索
            child: RefreshIndicator(
              onRefresh: () async {
                await showSearch(context: context, delegate: BujoSearchDelegate());
              },
              child: ReorderableListView.builder(
                padding: const EdgeInsets.only(top: 10, bottom: 80),
                buildDefaultDragHandles: false,
                onReorder: (oldIndex, newIndex) {
                  provider.reorderCollectionBullets(collectionId, oldIndex, newIndex);
                },
                itemCount: bullets.length,
                itemBuilder: (context, index) {
                  final b = bullets[index];
                  return ReorderableDelayedDragStartListener(
                    key: ValueKey(b.id),
                    index: index,
                    child: Slidable(
                      key: ValueKey(b.id),
                      groupTag: 'collection_list',
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
                      child: _buildListItem(context, provider, b),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickNewDate(BuildContext context, BujoProvider provider, Bullet b) async {
    final result = await showBujoDatePicker(context, initialDate: b.date ?? DateTime.now(), initialScope: b.scope);
    if (result != null) {
       if (result.date == null) provider.updateBulletFull(b.id, content: b.content, type: b.type, date: null, scope: BulletScope.none, collectionId: b.collectionId);
       else provider.moveBullet(b, result.date!, result.scope);
    }
  }

  Widget _buildListItem(BuildContext context, BujoProvider provider, Bullet b) {
    bool isCancelled = b.status == BulletStatus.cancelled;
    bool isCompleted = b.status == BulletStatus.completed;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        // 【核心修改】调用公共编辑框
        onTap: () => showBulletEditDialog(context, b),
        splashColor: Colors.blue.withValues(alpha: 0.1),
        highlightColor: Colors.grey.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            GestureDetector(
              onTap: b.type == 'task' ? () => provider.toggleStatus(b.id) : null,
              child: Container(padding: const EdgeInsets.only(right: 12), color: Colors.transparent, child: Icon(_getIcon(b), size: 14, color: (b.type == 'task' && !isCompleted && !isCancelled) ? Colors.black : Colors.grey)),
            ),
            Expanded(child: Text(b.content, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, height: 1.2, decoration: isCancelled ? TextDecoration.lineThrough : null, color: (isCompleted || isCancelled) ? Colors.grey : Colors.black87))),
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

  void _showRenameDialog(BuildContext context) {
    final provider = Provider.of<BujoProvider>(context, listen: false);
    // 这里因为是 StatelessWidget，需要重新获取 title。简单起见，从 Provider 的 collections 里拿
    String initialName = title; 
    // 更好的方式是传入 Collection 对象，但为了复用现有结构，我们暂时这样
    // 实际生产中建议 CollectionView 接收 Collection 对象
    
    final controller = TextEditingController(text: initialName);
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("重命名集子"), content: TextField(controller: controller, autofocus: true), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")), ElevatedButton(onPressed: () { if (controller.text.isNotEmpty && collectionId != null) { provider.renameCollection(collectionId!, controller.text); Navigator.pop(ctx); Navigator.pop(context); } }, child: const Text("保存"))]));
  }

  void _showDeleteCollectionDialog(BuildContext context) {
    final provider = Provider.of<BujoProvider>(context, listen: false);
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("删除集子"), content: const Text("确定要删除这个集子吗？"), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")), TextButton(onPressed: () { if (collectionId != null) { provider.deleteCollection(collectionId!); Navigator.pop(ctx); Navigator.pop(context); } }, style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text("删除"))]));
  }
}