import 'package:flutter/material.dart';
import 'src/services/ffi_service.dart';
import 'src/screens/home.dart';

final siftService = NativeService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await siftService.init();
  runApp(const SiftApp());
}

class SiftApp extends StatelessWidget {
  const SiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'sift',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4), brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD0BCFF), brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
