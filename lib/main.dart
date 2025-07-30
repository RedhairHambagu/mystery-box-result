import 'package:flutter/material.dart';
import 'pages/home_page_improved.dart';

void main() {
  runApp(const MyImprovedApp());
}

class MyImprovedApp extends StatelessWidget {
  const MyImprovedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '微店盲盒工具',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightGreen),
        useMaterial3: true,
      ),
      home: const HomePageImproved(),
      debugShowCheckedModeBanner: false,
    );
  }
}