import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/bullet.dart';
import '../models/collection.dart';
import '../providers/bujo_provider.dart';
import 'bujo_date_picker.dart';

// 静态方法调用
void showBulletEditDialog(BuildContext context, Bullet bullet) {
  final controller = TextEditingController(text: bullet.content);
  final provider = Provider.of<BujoProvider>(context, listen: false);
  
  String selectedType = bullet.type;
  DateTime? selectedDate = bullet.date;
  BulletScope selectedScope = bullet.scope;
  String? selectedCollectionId = bullet.collectionId;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        String collectionName = "集子";
        if (selectedCollectionId != null) {
           final c = provider.collections.firstWhere((e) => e.id == selectedCollectionId, orElse: () => Collection(id:'', name:'未知'));
           collectionName = c.name;
        }
        
        String dateStr = "日期";
        if (selectedDate != null) {
          if (selectedScope == BulletScope.day) dateStr = DateFormat('MM-dd').format(selectedDate!);
          else if (selectedScope == BulletScope.week) dateStr = "第${calculateWeekNumber(selectedDate!)}周";
          else if (selectedScope == BulletScope.month) dateStr = "${selectedDate!.month}月";
          else if (selectedScope == BulletScope.year) dateStr = "${selectedDate!.year}年";
        }

        return AlertDialog(
          title: const Text("编辑任务"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: controller, autofocus: true),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _buildTypeOption('task', Icons.fiber_manual_record, selectedType, (val) => setState(() => selectedType = val)),
                _buildTypeOption('event', Icons.radio_button_unchecked, selectedType, (val) => setState(() => selectedType = val)),
                _buildTypeOption('note', Icons.remove, selectedType, (val) => setState(() => selectedType = val)),
              ]),
              const SizedBox(height: 15),
              Row(children: [
                Expanded(
                  child: _buildStyledOption(
                    icon: Icons.calendar_today,
                    label: dateStr,
                    onTap: () async {
                      final res = await showBujoDatePicker(context, initialDate: selectedDate ?? DateTime.now(), initialScope: selectedScope);
                      if (res != null) {
                        setState(() {
                          selectedDate = res.date;
                          selectedScope = res.scope;
                        });
                      }
                    }
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStyledOption(
                    icon: Icons.folder_open,
                    label: collectionName,
                    isHighLighted: selectedCollectionId != null,
                    onTap: () {
                      showModalBottomSheet(context: context, builder: (_) => ListView(
                        shrinkWrap: true,
                        children: [
                          ...provider.collections.map((c) => ListTile(
                            title: Text(c.name),
                            onTap: () {
                              setState(() => selectedCollectionId = c.id);
                              Navigator.pop(context);
                            },
                          )),
                          if (selectedCollectionId != null)
                            ListTile(title: const Text("移除集子", style: TextStyle(color: Colors.red)), onTap: () { setState(() => selectedCollectionId = null); Navigator.pop(context); })
                        ],
                      ));
                    }
                  ),
                ),
              ])
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () {
                provider.deleteBullet(bullet.id);
                Navigator.pop(ctx);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text("删除"),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  provider.updateBulletFull(
                    bullet.id, 
                    content: controller.text, 
                    type: selectedType, 
                    date: selectedDate, 
                    scope: selectedScope, 
                    collectionId: selectedCollectionId
                  );
                  Navigator.pop(ctx);
                }
              },
              child: const Text("保存"),
            ),
          ],
        );
      },
    ),
  );
}

Widget _buildStyledOption({required IconData icon, required String label, bool isHighLighted = false, required VoidCallback onTap}) {
  return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8), decoration: BoxDecoration(color: isHighLighted ? Colors.blue : Colors.grey[100], borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 16, color: isHighLighted ? Colors.white : Colors.grey), const SizedBox(width: 4), Flexible(child: Text(label, style: TextStyle(fontSize: 12, color: isHighLighted ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis))])));
}

Widget _buildTypeOption(String type, IconData icon, String current, Function(String) onTap) {
  return GestureDetector(onTap: () => onTap(type), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: type == current ? Colors.blue.withValues(alpha: 0.1) : Colors.transparent, borderRadius: BorderRadius.circular(4), border: Border.all(color: type == current ? Colors.blue : Colors.transparent)), child: Icon(icon, color: type == current ? Colors.blue : Colors.grey, size: 18)));
}