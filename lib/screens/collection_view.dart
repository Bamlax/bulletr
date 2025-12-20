import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bujo_provider.dart';
import '../widgets/bujo_search_delegate.dart';
import '../widgets/bullet_list_builder.dart'; 
import '../models/bullet.dart'; 

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
          
          return RefreshIndicator(
            onRefresh: () async {
              await showSearch(context: context, delegate: BujoSearchDelegate());
            },
            child: BulletListBuilder(
              bullets: bullets,
              listTag: 'collection_view_$collectionId',
              collectionId: collectionId,
              scope: collectionId == null ? BulletScope.none : BulletScope.day,
            ),
          );
        },
      ),
    );
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