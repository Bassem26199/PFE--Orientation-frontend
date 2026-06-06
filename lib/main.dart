import 'package:flutter/material.dart';

import 'screens/public_navigation_screen.dart';

import 'services/auth_service.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.loadSession();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MediOrient',
      theme: AppTheme.lightTheme,

      // ✅ دائما الصفحة الرئيسية
      home: const PublicNavigationScreen(),
    );
  }
}