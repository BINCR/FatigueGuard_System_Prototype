import 'package:flutter/material.dart';
import 'login.dart';

void main() {
  runApp(const FatigueGuardApp());
}

class FatigueGuardApp extends StatelessWidget {
  const FatigueGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FatigueGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Manrope',
      ),
      home: const LoginPage(),
    );
  }
}