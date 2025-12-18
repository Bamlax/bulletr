import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bujo_provider.dart';
import '../screens/collection_view.dart';
import '../screens/settings_screen.dart';

class BujoDrawer extends StatelessWidget {
  const BujoDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          Stack(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: Colors.blue),
                accountName: const Text("bulletr", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                accountEmail: null,
                currentAccountPicture: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.book, color: Colors.blue),
                ),
              ),
              Positioned(
                top: 8 + MediaQuery.of(context).padding.top,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  },
                ),
              )
            ],
          ),
          
          ListTile(
            leading: const Icon(Icons.inbox, color: Colors.blue),
            // 【修改】去掉了英文
            title: const Text("收集箱"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const CollectionView(title: "收集箱", collectionId: null))
              );
            },
          ),
          
          const Divider(),
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("我的集子", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
            ),
          ),

          Expanded(
            child: Consumer<BujoProvider>(
              builder: (context, provider, _) {
                // Provider 中已经做了排序
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: provider.collections.length,
                  itemBuilder: (context, index) {
                    final collection = provider.collections[index];
                    return ListTile(
                      leading: const Icon(Icons.folder_open, color: Colors.orange),
                      title: Text(collection.name),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (_) => CollectionView(title: collection.name, collectionId: collection.id))
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.add, color: Colors.blue),
            title: const Text("新建集子"),
            onTap: () {
              final provider = Provider.of<BujoProvider>(context, listen: false);
              Navigator.pop(context);
              _showAddCollectionDialog(context, provider);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showAddCollectionDialog(BuildContext context, BujoProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("新建集子"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "集子名称 (如：书单、旅行计划)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.addCollection(controller.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text("创建"),
          )
        ],
      ),
    );
  }
}