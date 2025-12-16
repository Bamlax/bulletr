import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bullet.dart';
import '../widgets/add_bullet_sheet.dart';
import '../providers/bujo_provider.dart';

import 'daily_view.dart';
import 'weekly_view.dart';
import 'monthly_view.dart';
import 'yearly_view.dart';
import '../widgets/bujo_drawer.dart'; // 引入 Drawer

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isFabVisible = true; // 【新增】控制 FAB 的显示状态

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
      // 【新增】监听 Drawer 状态
      onDrawerChanged: (isOpened) {
        setState(() {
          // 如果打开了侧边栏，FAB 就不可见；关闭了就可见
          _isFabVisible = !isOpened;
        });
      },
      
      // 注意：这里我们不再在 Scaffold 层面直接加 drawer，
      // 而是通过 onDrawerChanged 配合子页面的 drawer 来控制。
      // 但为了让 onDrawerChanged 生效，Scaffold 需要知道 drawer 的存在。
      // 不过我们的架构是子页面 Scaffold 自带 drawer。
      // 实际上，外层 HomeScreen 的 Scaffold 不负责显示内容，只负责底部导航。
      // 内容在 body 里。
      // 所以这里的 onDrawerChanged 监听的是 HomeScreen 自己的 Drawer。
      // 但子页面也有 Scaffold。这是一个嵌套 Scaffold 结构。
      // 为了让“侧边栏打开时隐藏FAB”生效，我们需要把 FAB 放在 HomeScreen，
      // 而 Drawer 放在子页面会导致 HomeScreen 监听不到。
      
      // 【修正架构】为了完美实现需求，我们将 Drawer 统一提到 HomeScreen 来管理。
      // 这样 HomeScreen 就能完美控制 FAB 的显隐了。
      drawer: const BujoDrawer(),

      body: pages[_currentIndex],
      
      // 【修改】根据状态决定是否显示按钮
      floatingActionButton: _isFabVisible ? FloatingActionButton(
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
      ) : null, // 隐藏时不渲染
      
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