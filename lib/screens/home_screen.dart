import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bullet.dart';
import '../widgets/add_bullet_sheet.dart';
import '../providers/bujo_provider.dart';
import '../widgets/bujo_drawer.dart';

import 'daily_view.dart';
import 'weekly_view.dart';
import 'monthly_view.dart';
import 'yearly_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void _switchTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const DailyView(),
      WeeklyView(onJumpToDay: () => _switchTab(0)),
      MonthlyView(onJumpToDay: () => _switchTab(0)),
      YearlyView(onJumpToMonth: () => _switchTab(2)),
    ];

    return Scaffold(
      drawer: const BujoDrawer(),

      body: pages[_currentIndex],
      
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          BulletScope scope = BulletScope.day;
          if (_currentIndex == 1) scope = BulletScope.week;
          if (_currentIndex == 2) scope = BulletScope.month;
          if (_currentIndex == 3) scope = BulletScope.year;

          final focusDate = Provider.of<BujoProvider>(context, listen: false).focusDate;

          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => AddBulletSheet(
              initialDate: focusDate,
              initialScope: scope,
            ),
          );
        },
      ),
      
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        height: 65,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined), 
            selectedIcon: Icon(Icons.today),
            label: '日'
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_view_week_outlined), 
            selectedIcon: Icon(Icons.calendar_view_week),
            label: '周'
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined), 
            selectedIcon: Icon(Icons.calendar_month),
            label: '月'
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined), 
            selectedIcon: Icon(Icons.calendar_today),
            label: '年'
          ),
        ],
      ),
    );
  }
}