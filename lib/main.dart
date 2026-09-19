import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'login.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive CE local storage.
  await Hive.initFlutter();

  // Stores every driving session.
  await Hive.openBox<dynamic>(
    StorageService.sessionsBoxName,
  );

  // Stores fatigue and distraction detection events.
  await Hive.openBox<dynamic>(
    StorageService.eventsBoxName,
  );

  runApp(const FatigueGuardApp());
}

class FatigueGuardApp extends StatelessWidget {
  const FatigueGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FatigueGuard',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3525CD),
        fontFamily: 'Manrope',
      ),
      home: const LoginPage(),
    );
  }
}