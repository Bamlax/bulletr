import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/bujo_provider.dart';
import '../models/bullet.dart';
import '../models/collection.dart';
import 'bullet_edit_dialog.dart';
import 'bujo_date_picker.dart';

class BujoSearchDelegate extends SearchDelegate {
  @override
  String get searchFieldLabel => "搜索任务...";

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.grey),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear, color: Colors.grey),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.black),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final provider = Provider.of<BujoProvider>(context, listen: false);
    
    // 1. 过滤
    final results = provider.bullets.where((b) {
      return b.content.toLowerCase().contains(query.toLowerCase());
    }).toList();

    // 2. 【核心修改】按修改时间倒序排列 (最新的在前)
    results.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (results.isEmpty) {
      return const Center(child: Text("没有找到相关记录", style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final b = results[index];
        return ListTile(
          leading: Icon(_getIcon(b), size: 14, color: Colors.grey),
          title: Text(
            b.content,
            style: TextStyle(
              decoration: b.status == BulletStatus.cancelled ? TextDecoration.lineThrough : null,
              color: b.status != BulletStatus.open ? Colors.grey : Colors.black,
            ),
          ),
          subtitle: Text(
            _getMetaInfo(b, provider), 
            style: const TextStyle(fontSize: 12, color: Colors.grey)
          ),
          onTap: () {
            showBulletEditDialog(context, b);
          },
        );
      },
    );
  }

  String _getMetaInfo(Bullet b, BujoProvider provider) {
    String typeStr;
    switch (b.type) {
      case 'event': typeStr = '事件'; break;
      case 'note': typeStr = '笔记'; break;
      default: typeStr = '任务'; break;
    }

    String scopeStr = "收集箱";
    if (b.date != null) {
      switch (b.scope) {
        case BulletScope.day:
          scopeStr = DateFormat('MM-dd').format(b.date!);
          break;
        case BulletScope.week:
          scopeStr = "${b.date!.year}年 第${calculateWeekNumber(b.date!)}周";
          break;
        case BulletScope.month:
          scopeStr = "${b.date!.year}年 ${b.date!.month}月";
          break;
        case BulletScope.year:
          scopeStr = "${b.date!.year}年";
          break;
        case BulletScope.none:
        default:
          scopeStr = "收集箱"; 
          break;
      }
    }

    String collectionStr = "";
    if (b.collectionId != null) {
      final c = provider.collections.firstWhere(
        (c) => c.id == b.collectionId, 
        orElse: () => Collection(id: '', name: '?')
      );
      if (c.name != '?') {
        collectionStr = " @${c.name}";
      }
    }

    return "$typeStr • $scopeStr$collectionStr";
  }

  IconData _getIcon(Bullet b) {
    if (b.type == 'task') {
      if (b.status == BulletStatus.completed) return Icons.check_circle;
      if (b.status == BulletStatus.cancelled) return Icons.close;
      return Icons.circle;
    }
    if (b.type == 'event') return Icons.radio_button_unchecked;
    if (b.type == 'note') return Icons.remove;
    return Icons.circle;
  }
}