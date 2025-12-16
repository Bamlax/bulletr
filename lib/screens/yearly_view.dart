import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/bujo_provider.dart';
import '../models/bullet.dart';
import '../models/collection.dart';
import '../widgets/bujo_drawer.dart';
import '../widgets/bujo_date_picker.dart'; // 引入日期选择器

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
    _displayedYear = _anchorDate;
    _pageController = PageController(initialPage: _anchorIndex);
  }

  @override
  Widget build(BuildContext context) {
    final year = _displayedYear.year;

    return Scaffold(
      drawer: const BujoDrawer(),
      appBar: AppBar(
        title: Text("$year年", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
    return Column(
      children: [
        _buildYearlyPool(yearDate),
        Expanded(
          child: Container(
            color: Colors.white,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: 12,
              itemBuilder: (context, i) {
                // 每个月的第一天
                final monthDate = DateTime(yearDate.year, i + 1, 1);
                return _buildMonthDropTarget(monthDate);
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- 顶部年度任务池 ---
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
            
            // 确保有高度可以接收拖拽
            if (yearlyBullets.isEmpty && !isHovering) {
               return Container(height: 20, width: double.infinity, color: Colors.transparent);
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
                    ...yearlyBullets.map((b) => _buildDraggablePoolStrip(b)),
                  if (isHovering)
                     const Center(child: Text("放回到年度目标", style: TextStyle(color: Colors.blue, fontSize: 12))),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 顶部池子的拖拽项
  Widget _buildDraggablePoolStrip(Bullet bullet) {
    final screenWidth = MediaQuery.of(context).size.width;
    return LongPressDraggable<Bullet>(
      data: bullet,
      feedback: Material(
        elevation: 6,
        color: Colors.transparent,
        child: Container(
          width: screenWidth - 32,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
          child: _buildStripContent(bullet, isDragging: true),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _buildStripContent(bullet)),
      child: _buildStripContent(bullet),
    );
  }

  // --- 月份行 ---
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
            border: Border(bottom: BorderSide(color: Colors.grey[100]!, width: 1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧：月份头 (点击跳转)
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
                      color: isCurrentMonth ? Colors.blue : Colors.black87
                    )
                  ),
                ),
              ),

              // 右侧：任务列表 (点击编辑)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Consumer<BujoProvider>(
                    builder: (ctx, provider, _) {
                      final monthlyBullets = provider.getBulletsByScope(monthDate, BulletScope.month);
                      if (monthlyBullets.isEmpty) return const SizedBox(height: 36); 

                      return Column(
                        children: monthlyBullets.map((b) => _buildDraggableStrip(b)).toList(),
                      );
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

  // 列表里的拖拽项
  Widget _buildDraggableStrip(Bullet bullet) {
    final screenWidth = MediaQuery.of(context).size.width;
    return LongPressDraggable<Bullet>(
      data: bullet,
      feedback: Material(
        elevation: 6,
        color: Colors.transparent,
        child: Container(
          width: screenWidth - 70, // 减去左侧宽度
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
          child: _buildStripContent(bullet, isDragging: true),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _buildStripContent(bullet)),
      child: _buildStripContent(bullet),
    );
  }

  // 任务内容渲染
  Widget _buildStripContent(Bullet bullet, {bool isDragging = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        // 非拖拽时点击弹出编辑
        onTap: isDragging ? null : () => _showEditDialog(context, bullet),
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          width: double.infinity,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  _getIcon(bullet), 
                  size: 10,
                  color: (bullet.type == 'task' && !bullet.isCompleted) ? Colors.black : Colors.grey,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  bullet.content, 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    decoration: bullet.isCompleted ? TextDecoration.lineThrough : null,
                    color: bullet.isCompleted ? Colors.grey : Colors.black87
                  )
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
      if (b.isCompleted) return Icons.close;
      return Icons.circle;
    }
    if (b.type == 'event') return Icons.circle_outlined;
    if (b.type == 'note') return Icons.remove;
    return Icons.circle;
  }

  // --- 全功能编辑弹窗 ---
  void _showEditDialog(BuildContext context, Bullet bullet) {
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
          
          // 正确的日期显示逻辑
          String dateStr = "日期";
          if (selectedDate != null) {
            if (selectedScope == BulletScope.day) {
              dateStr = DateFormat('MM-dd').format(selectedDate!);
            } else if (selectedScope == BulletScope.week) {
              dateStr = "第${calculateWeekNumber(selectedDate!)}周";
            } else if (selectedScope == BulletScope.month) {
              dateStr = "${selectedDate!.month}月";
            } else if (selectedScope == BulletScope.year) {
              dateStr = "${selectedDate!.year}年";
            }
          }

          return AlertDialog(
            title: const Text("编辑任务"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: controller, autofocus: true),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTypeOption('task', Icons.fiber_manual_record, selectedType, (val) => setState(() => selectedType = val)),
                    _buildTypeOption('event', Icons.radio_button_unchecked, selectedType, (val) => setState(() => selectedType = val)),
                    _buildTypeOption('note', Icons.remove, selectedType, (val) => setState(() => selectedType = val)),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
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
                  ],
                )
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isHighLighted ? Colors.blue : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isHighLighted ? Colors.white : Colors.grey),
            const SizedBox(width: 4),
            Flexible(child: Text(label, style: TextStyle(fontSize: 12, color: isHighLighted ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption(String type, IconData icon, String current, Function(String) onTap) {
    final isSelected = type == current;
    return GestureDetector(
      onTap: () => onTap(type),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isSelected ? Colors.blue : Colors.transparent),
        ),
        child: Icon(icon, color: isSelected ? Colors.blue : Colors.grey, size: 18),
      ),
    );
  }
}