import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bullet.dart';

class DateResult {
  final DateTime? date;
  final BulletScope scope;
  DateResult(this.date, this.scope);
}

// 辅助：计算周数
int calculateWeekNumber(DateTime date) {
  DateTime startOfYear = DateTime(date.year, 1, 1);
  int dayOfYear = int.parse(DateFormat("D").format(date));
  int weekNum = ((dayOfYear - date.weekday + 10) / 7).floor();
  return weekNum;
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
  late DateTime? _selectedDate;
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
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      onDateChanged: (value) => _confirmSelection(value, BulletScope.day),
    );
  }

  Widget _buildWeekPicker() {
    final currentWeek = _selectedDate != null ? calculateWeekNumber(_selectedDate!) : calculateWeekNumber(DateTime.now());
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text("当前选中：第$currentWeek周 (点击任意日期选择)", style: const TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: CalendarDatePicker(
            initialDate: _selectedDate ?? DateTime.now(),
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
    final year = _selectedDate?.year ?? now.year;
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
              final isCurrentMonth = month == now.month && year == now.year;
              return InkWell(
                onTap: () => _confirmSelection(DateTime(year, month, 1), BulletScope.month),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isCurrentMonth ? Colors.blue.withValues(alpha: 0.1) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: isCurrentMonth ? Border.all(color: Colors.blue) : null,
                  ),
                  child: Text("$month月", style: TextStyle(
                    color: isCurrentMonth ? Colors.blue : Colors.black87,
                    fontWeight: isCurrentMonth ? FontWeight.bold : FontWeight.normal
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
      selectedDate: _selectedDate ?? DateTime.now(),
      onChanged: (value) => _confirmSelection(value, BulletScope.year),
    );
  }
}