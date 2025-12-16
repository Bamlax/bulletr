import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/bujo_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN', null);
  
  runApp(const BujoApp());
}

class BujoApp extends StatelessWidget {
  const BujoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BujoProvider()),
      ],
      child: MaterialApp(
        title: 'bulletr',
        // 【修改1】去掉右上角的 Debug 标签
        debugShowCheckedModeBanner: false, 
        theme: ThemeData(
          useMaterial3: true,
          // 【修改2】主题色改为淡蓝色
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}