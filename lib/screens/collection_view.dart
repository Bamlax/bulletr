import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../providers/bujo_provider.dart';
import '../models/bullet.dart';
import '../models/collection.dart';
import '../widgets/bujo_date_picker.dart';

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
        onTap: () => _showEditDialog(context, b),
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

  void _showRenameDialog(BuildContext context) {
    final provider = Provider.of<BujoProvider>(context, listen: false);
    final controller = TextEditingController(text: title);
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("重命名集子"), content: TextField(controller: controller, autofocus: true), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")), ElevatedButton(onPressed: () { if (controller.text.isNotEmpty && collectionId != null) { provider.renameCollection(collectionId!, controller.text); Navigator.pop(ctx); Navigator.pop(context); } }, child: const Text("保存"))]));
  }

  void _showDeleteCollectionDialog(BuildContext context) {
    final provider = Provider.of<BujoProvider>(context, listen: false);
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("删除集子"), content: const Text("确定要删除这个集子吗？"), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")), TextButton(onPressed: () { if (collectionId != null) { provider.deleteCollection(collectionId!); Navigator.pop(ctx); Navigator.pop(context); } }, style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text("删除"))]));
  }
}