import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/storage_service.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/onboarding/password_setup_screen.dart';
import 'screens/onboarding/directory_setup_screen.dart';
import 'screens/auth/password_verify_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/settings/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  await initializeDateFormatting('zh_CN', null);
  Intl.defaultLocale = 'zh_CN';
  
  runApp(const ClipNoteApp());
}

class ClipNoteApp extends StatelessWidget {
  const ClipNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClipNote',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const InitialScreen(),
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/password_setup': (context) => const PasswordSetupScreen(),
        '/directory_setup': (context) => const DirectorySetupScreen(),
        '/password_verify': (context) => const PasswordVerifyScreen(),
        '/home': (context) => const HomeScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

/// 初始屏幕
class InitialScreen extends StatelessWidget {
  const InitialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getInitialRoute(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final data = snapshot.data ?? {'route': '/welcome'};
        final route = data['route'] as String;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacementNamed(route);
        });

        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getInitialRoute() async {
    final storage = StorageService();
    final isFirstLaunch = await storage.isFirstLaunch();

    if (isFirstLaunch) {
      // 首次启动，显示欢迎
      return {'route': '/welcome'};
    }

    // 不是首次启动，检查是否密码币的
    final hasPassword = await storage.hasPassword();
    if (hasPassword) {
      // 密码，显示验证页面
      return {'route': '/password_verify'};
    }

    // 没密码，直接进入主界面
    return {'route': '/home'};
  }
}
