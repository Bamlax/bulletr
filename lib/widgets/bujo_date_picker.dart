import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bullet.dart';

class DateResult {
  final DateTime? date;
  final BulletScope scope;
  DateResult(this.date, this.scope);
}

// 【核心修复】周数计算逻辑：以本周的“周日”所在的年份为基准
int calculateWeekNumber(DateTime date) {
  // 1. 找到该日期所在周的周一 (忽略时分秒)
  DateTime monday = DateTime(date.year, date.month, date.day)
      .subtract(Duration(days: date.weekday - 1));
  
  // 2. 找到该周的周日
  DateTime sunday = monday.add(const Duration(days: 6));
  
  // 3. 确定这周属于哪一年 (以周日为准)
  // 如果周日是 2025年，那这周就是 2025年的周
  int targetYear = sunday.year;
  
  // 4. 找到目标年份的 1月1日
  DateTime jan1 = DateTime(targetYear, 1, 1);
  
  // 5. 找到 1月1日 所在周的周一
  // (既然 1月1日 所在的周是第一周，那我们就以它的周一为起点)
  DateTime jan1Monday = jan1.subtract(Duration(days: jan1.weekday - 1));
  
  // 6. 计算当前周一距离 1月1日周一 隔了几个星期
  // 结果 + 1 就是周数
  int weekDiff = (monday.difference(jan1Monday).inDays / 7).round();
  
  return weekDiff + 1;
}

Future<DateResult?> showBujoDatePicker(BuildContext context, {
  required DateTime initialDate,
  required BulletScope initialScope,
}) {
  return showDialog<DateResult>(
    context: context,
    builder: (ctx) => _BujoDatePickerDialog(initialDate: initialDate, initialScope: initialScope),
  );
}

class _BujoDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final BulletScope initialScope;

  const _BujoDatePickerDialog({required this.initialDate, required this.initialScope});

  @override
  State<_BujoDatePickerDialog> createState() => _BujoDatePickerDialogState();
}

class _BujoDatePickerDialogState extends State<_BujoDatePickerDialog> {
  late DateTime _selectedDate; 
  late BulletScope _selectedScope;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _selectedScope = widget.initialScope;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: _getInitialTabIndex(),
      child: AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: const TabBar(
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: [Tab(text: "日"), Tab(text: "周"), Tab(text: "月"), Tab(text: "年")],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 350,
          child: TabBarView(
            children: [
              _buildDayPicker(),
              _buildWeekPicker(),
              _buildMonthPicker(),
              _buildYearPicker(),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, DateResult(null, BulletScope.none)),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text("清除"),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  int _getInitialTabIndex() {
    switch (_selectedScope) {
      case BulletScope.week: return 1;
      case BulletScope.month: return 2;
      case BulletScope.year: return 3;
      default: return 0;
    }
  }

  void _confirmSelection(DateTime date, BulletScope scope) {
    Navigator.pop(context, DateResult(date, scope));
  }

  Widget _buildDayPicker() {
    return CalendarDatePicker(
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      onDateChanged: (value) => _confirmSelection(value, BulletScope.day),
    );
  }

  Widget _buildWeekPicker() {
    final currentWeek = calculateWeekNumber(_selectedDate);
    // 计算显示的范围 (周一到周日)
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    
    // 【显示修复】如果这周跨年且被算作下一年，显示下一年的年份
    final year = endOfWeek.year; 
    
    final rangeStr = "${DateFormat('MM.dd').format(startOfWeek)} - ${DateFormat('MM.dd').format(endOfWeek)}";

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: Colors.blue.withValues(alpha: 0.05),
          width: double.infinity,
          child: Column(
            children: [
              // 显示：2025年 第1周
              Text("$year年 第 $currentWeek 周", style: const TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold)),
              Text(rangeStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              const Text("(点击下方任意日期选择)", style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
        Expanded(
          child: CalendarDatePicker(
            initialDate: _selectedDate,
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            onDateChanged: (value) => _confirmSelection(value, BulletScope.week),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthPicker() {
    final now = DateTime.now();
    // 默认显示选中日期的年份
    final year = _selectedDate.year;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text("$year年", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, childAspectRatio: 1.5, crossAxisSpacing: 10, mainAxisSpacing: 10,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              final isSelectedMonth = month == _selectedDate.month && year == _selectedDate.year;
              return InkWell(
                onTap: () => _confirmSelection(DateTime(year, month, 1), BulletScope.month),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelectedMonth ? Colors.blue.withValues(alpha: 0.1) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: isSelectedMonth ? Border.all(color: Colors.blue) : null,
                  ),
                  child: Text("$month月", style: TextStyle(
                    color: isSelectedMonth ? Colors.blue : Colors.black87,
                    fontWeight: isSelectedMonth ? FontWeight.bold : FontWeight.normal
                  )),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildYearPicker() {
    return YearPicker(
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      selectedDate: _selectedDate,
      onChanged: (value) => _confirmSelection(value, BulletScope.year),
    );
  }
}