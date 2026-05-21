import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'providers/auth_provider.dart';
import 'providers/reminder_provider.dart';
import 'services/notification_service.dart';

import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz_lib;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  tz_lib.setLocalLocation(tz_lib.getLocation('Asia/Jakarta'));
  await NotificationService.init();
  
  final authProvider = AuthProvider();
  await authProvider.periksaSesi();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => authProvider),
        ChangeNotifierProvider(create: (_) => PengingatProvider()),
      ],
      child: const RemindMePlusApp(),
    ),
  );
}

class RemindMePlusApp extends StatelessWidget {
  const RemindMePlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RemindMe+',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const MainNavigation(),
      },
    );
  }
}
