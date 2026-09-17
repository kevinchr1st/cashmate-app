import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/splash_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/owner/owner_navigation_page.dart';
import 'pages/staff/staff_navigation_page.dart';
import 'utils/app_theme.dart';

/// Notifier global untuk mode tema (terang/gelap).
/// Dipakai oleh profile_page.dart lewat `_changeThemeMode()`.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() {
  runApp(const CashMateApp());
}

class CashMateApp extends StatefulWidget {
  const CashMateApp({super.key});

  @override
  State<CashMateApp> createState() => _CashMateAppState();
}

class _CashMateAppState extends State<CashMateApp> {
  @override
  void initState() {
    super.initState();
    _loadSavedThemeMode();
  }

  // Memuat preferensi tema yang tersimpan (mengikuti key 'is_dark_mode'
  // yang sudah dipakai di profile_page.dart -> _changeThemeMode()).
  Future<void> _loadSavedThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode') ?? false;
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'CashMate UMKM',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashPage(),
            '/login': (context) => const LoginPage(),
            '/signup': (context) => const RegisterPage(),
            '/main': (context) => const OwnerNavigationPage(),
            '/dashboard': (context) => const OwnerNavigationPage(),
            '/staff-main': (context) => const StaffNavigationPage(),
          },
        );
      },
    );
  }
}