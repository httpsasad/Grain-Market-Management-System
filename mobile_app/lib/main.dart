import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'services/language_service.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.getBaseUrl();
  await LanguageService().initLanguage();
  runApp(const MandiErpApp());
}

class MandiErpApp extends StatefulWidget {
  const MandiErpApp({super.key});

  @override
  State<MandiErpApp> createState() => _MandiErpAppState();
}

class _MandiErpAppState extends State<MandiErpApp> {
  bool isLoggedIn = false;
  bool isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await ApiService.getToken();
    if (mounted) {
      setState(() {
        isLoggedIn = (token != null && token.isNotEmpty);
        isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Galla Mandi ERP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: isChecking
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : isLoggedIn
              ? DashboardScreen(
                  onLogout: () async {
                    await ApiService.logout();
                    setState(() => isLoggedIn = false);
                  },
                )
              : LoginScreen(
                  onLoginSuccess: () {
                    setState(() => isLoggedIn = true);
                  },
                ),
    );
  }
}
