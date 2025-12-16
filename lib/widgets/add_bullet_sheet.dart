import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/bullet.dart';
import '../models/collection.dart';
import '../providers/bujo_provider.dart';
import 'bujo_date_picker.dart'; // 引入刚才写的日期选择器

class AddBulletSheet extends StatefulWidget {
  final DateTime initialDate;
  final BulletScope initialScope;

  const AddBulletSheet({super.key, required this.initialDate, required this.initialScope});

  @override
  State<AddBulletSheet> createState() => _AddBulletSheetState();
}

class _AddBulletSheetState extends State<AddBulletSheet> {
  late TextEditingController _controller;
  DateTime? _selectedDate; 
  late BulletScope _selectedScope;
  String _selectedType = 'task';
  String? _selectedCollectionId; 

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _selectedDate = widget.initialDate;
    _selectedScope = widget.initialScope;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 16
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: "要做什么...", border: InputBorder.none),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.blue),
                onPressed: _submit,
              )
            ],
          ),
          const Divider(),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTypeSelector(),
                const SizedBox(width: 10),
                _buildStyledChip(
                  icon: Icons.calendar_today,
                  label: _formatDateLabel(),
                  isActive: true,
                  onTap: _pickDate,
                ),
                const SizedBox(width: 10),
                _buildCollectionSelector(),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // 调用新的日期选择器
  void _pickDate() async {
    final result = await showBujoDatePicker(
      context, 
      initialDate: _selectedDate ?? DateTime.now(), 
      initialScope: _selectedScope
    );
    if (result != null) {
      setState(() {
        _selectedDate = result.date;
        _selectedScope = result.scope;
      });
    }
  }

  Widget _buildTypeSelector() {
    IconData icon;
    switch (_selectedType) {
      case 'event': icon = Icons.radio_button_unchecked; break;
      case 'note': icon = Icons.remove; break;
      default: icon = Icons.fiber_manual_record;
    }
    return PopupMenuButton<String>(
      initialValue: _selectedType,
      tooltip: "选择类型",
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: _buildStyledChip(
        icon: icon,
        label: _getTypeLabel(_selectedType),
        isActive: true,
        onTap: null, 
      ),
      onSelected: (val) => setState(() => _selectedType = val),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'task', child: Row(children: [Icon(Icons.fiber_manual_record, size: 16), SizedBox(width: 8), Text("任务")])),
        const PopupMenuItem(value: 'event', child: Row(children: [Icon(Icons.radio_button_unchecked, size: 16), SizedBox(width: 8), Text("事件")])),
        const PopupMenuItem(value: 'note', child: Row(children: [Icon(Icons.remove, size: 16), SizedBox(width: 8), Text("笔记")])),
      ],
    );
  }

  Widget _buildCollectionSelector() {
    final collections = Provider.of<BujoProvider>(context, listen: false).collections;
    final currentName = _selectedCollectionId == null 
        ? "集子" // 默认文字
        : collections.firstWhere((c) => c.id == _selectedCollectionId, orElse: () => Collection(id: '', name: '未知')).name;

    return PopupMenuButton<String?>(
      initialValue: _selectedCollectionId,
      tooltip: "选择集子",
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: _buildStyledChip(
        icon: Icons.folder_open,
        label: currentName,
        isActive: true,
        isHighLighted: _selectedCollectionId != null, 
        onTap: null,
      ),
      onSelected: (val) {
        setState(() {
          if (_selectedCollectionId == val) {
            _selectedCollectionId = null; // 再次点击取消
          } else {
            _selectedCollectionId = val;
          }
        });
      },
      itemBuilder: (context) {
        return [
          if (collections.isEmpty)
            const PopupMenuItem<String?>(enabled: false, child: Text("暂无集子，请先在侧边栏创建", style: TextStyle(fontSize: 12))),
          ...collections.map((c) => PopupMenuItem<String?>(
            value: c.id,
            child: Text(c.name),
          )),
        ];
      },
    );
  }

  Widget _buildStyledChip({
    required IconData icon, 
    required String label, 
    required bool isActive, 
    bool isHighLighted = false,
    VoidCallback? onTap
  }) {
    final bgColor = isHighLighted ? Colors.blue : (isActive ? Colors.grey[100] : Colors.grey[50]);
    final fgColor = isHighLighted ? Colors.white : (isActive ? Colors.black87 : Colors.grey[300]);

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20), 
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isHighLighted ? Colors.white : (isActive ? Colors.black54 : Colors.grey[300])),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label, 
              style: TextStyle(fontSize: 13, color: fgColor, fontWeight: isHighLighted ? FontWeight.bold : FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (onTap != null && isActive) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }

  String _getTypeLabel(String type) => type == 'task' ? '任务' : (type == 'event' ? '事件' : '笔记');

  String _formatDateLabel() {
    if (_selectedDate == null) return "日期";
    if (_selectedScope == BulletScope.day) return DateFormat('MM-dd').format(_selectedDate!);
    if (_selectedScope == BulletScope.week) return "第${DateFormat('w').format(_selectedDate!)}周";
    if (_selectedScope == BulletScope.month) return "${_selectedDate!.month}月";
    return "${_selectedDate!.year}年";
  }

  void _submit() {
    if (_controller.text.isNotEmpty) {
      Provider.of<BujoProvider>(context, listen: false).addBullet(
        content: _controller.text,
        date: _selectedDate,
        type: _selectedType,
        scope: _selectedScope,
        collectionId: _selectedCollectionId,
      );
      Navigator.pop(context);
    }
  }
}