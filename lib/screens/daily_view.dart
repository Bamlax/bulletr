import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/bujo_provider.dart';
import '../models/bullet.dart';
import '../widgets/bujo_drawer.dart';
import '../widgets/bujo_search_delegate.dart';
import '../widgets/bullet_list_builder.dart'; 

class DailyView extends StatefulWidget {
  const DailyView({super.key});

  @override
  State<DailyView> createState() => _DailyViewState();
}

class _DailyViewState extends State<DailyView> {
  late PageController _pageController;
  late DateTime _displayedDate;
  final DateTime _anchorDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  final int _anchorIndex = 1000;

  @override
  void initState() {
    super.initState();
    final rawFocusDate = Provider.of<BujoProvider>(context, listen: false).focusDate;
    final focusDate = DateTime(rawFocusDate.year, rawFocusDate.month, rawFocusDate.day);
    _displayedDate = focusDate;
    final diffDays = focusDate.difference(_anchorDate).inDays;
    _pageController = PageController(initialPage: _anchorIndex + diffDays);
  }

  @override
  Widget build(BuildContext context) {
    final titleString = DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN').format(_displayedDate);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: GestureDetector(
          onLongPress: () {
            _pageController.animateToPage(
              _anchorIndex, 
              duration: const Duration(milliseconds: 300), 
              curve: Curves.easeInOut
            );
          },
          child: Text(titleString, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          final newDate = _anchorDate.add(Duration(days: index - _anchorIndex));
          setState(() { _displayedDate = newDate; });
          Provider.of<BujoProvider>(context, listen: false).setFocusDate(newDate);
        },
        itemBuilder: (context, index) {
          final date = _anchorDate.add(Duration(days: index - _anchorIndex));
          return _buildSingleDayPage(date);
        },
      ),
    );
  }

  Widget _buildSingleDayPage(DateTime date) {
    return Consumer<BujoProvider>(
      builder: (context, provider, child) {
        final bullets = provider.getBulletsByScope(date, BulletScope.day);
        
        return RefreshIndicator(
          onRefresh: () async {
            await showSearch(context: context, delegate: BujoSearchDelegate());
          },
          child: BulletListBuilder(
            bullets: bullets,
            listTag: 'daily_view_$date', 
            date: date,
            scope: BulletScope.day,
          ),
        );
      },
    );
  }
}