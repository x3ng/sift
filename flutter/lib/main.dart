import 'package:flutter/material.dart';
import 'src/services/api.dart';
import 'src/screens/home.dart';

final siftService = SiftService();

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
      theme: ThemeData(
        colorSchemeSeed: Colors.amber,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.amber,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const HomeScreen(),
    );
  }
}
