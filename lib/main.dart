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
        // 【修改】创建 Provider 时立即调用 loadData
        ChangeNotifierProvider(create: (_) => BujoProvider()..loadData()),
      ],
      child: MaterialApp(
        title: 'bulletr',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          // 统一使用更优雅的字体
          fontFamily: 'Roboto', 
        ),
        home: const HomeScreen(),
      ),
    );
  }
}