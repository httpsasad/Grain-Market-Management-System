import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isSignup = false;
  bool isLoading = false;
  final langService = LanguageService();

  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  // Signup fields
  final shopNameCtrl = TextEditingController();
  final ownerNameCtrl = TextEditingController();
  final mobileCtrl = TextEditingController();
  final cityCtrl = TextEditingController(text: 'Sargodha');
  final serverUrlCtrl = TextEditingController(text: ApiService.baseUrl);

  @override
  void initState() {
    super.initState();
    serverUrlCtrl.text = ApiService.baseUrl;
    langService.addListener(_onLangChanged);
  }

  @override
  void dispose() {
    langService.removeListener(_onLangChanged);
    super.dispose();
  }

  void _onLangChanged() {
    if (mounted) setState(() {});
  }

  void _showServerConfig() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(langService.t('Server Connection Setup', 'سرور کنکشن سیٹ اپ')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(langService.t(
              'Enter Server URL (Public domain, Ngrok, or Local IP):\nExample: https://mandi.trycloudflare.com or http://192.168.1.17:8000',
              'سرور URL اینٹر کریں (پبلک ڈومین، اینگراک یا لوکل آئی پی)',
            ), style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: serverUrlCtrl,
              decoration: const InputDecoration(labelText: 'Server URL'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(langService.t('Cancel', 'منسوخ')),
          ),
          ElevatedButton(
            onPressed: () async {
              await ApiService.setBaseUrl(serverUrlCtrl.text);
              if (mounted) Navigator.pop(ctx);
            },
            child: Text(langService.t('Save', 'محفوظ کریں')),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (usernameCtrl.text.isEmpty || passwordCtrl.text.isEmpty) {
      _showError(langService.t('Please fill username and password', 'براہ کرم یوزر نیم اور پاسورڈ درج کریں'));
      return;
    }

    setState(() => isLoading = true);
    try {
      if (isSignup) {
        final res = await ApiService.signup(
          username: usernameCtrl.text.trim(),
          shopName: shopNameCtrl.text.trim(),
          ownerName: ownerNameCtrl.text.trim(),
          mobile: mobileCtrl.text.trim(),
          city: cityCtrl.text.trim(),
          password: passwordCtrl.text.trim(),
        );
        if (res['success']) {
          widget.onLoginSuccess();
        } else {
          _showError(res['error']);
        }
      } else {
        final res = await ApiService.login(usernameCtrl.text.trim(), passwordCtrl.text.trim());
        if (res['success']) {
          widget.onLoginSuccess();
        } else {
          _showError(res['error']);
        }
      }
    } catch (e) {
      _showError(langService.t('Connection error! Please check server URL in settings.', 'کنکشن میں مسئلہ! سرور URL چیک کریں'));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F5132), Color(0xFF064E3B), Color(0xFF022C22)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.language, color: Color(0xFF0F5132)),
                            tooltip: 'Switch Language',
                            onPressed: () => langService.toggleLanguage(),
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F5132).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.agriculture, size: 36, color: Color(0xFF0F5132)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings, color: Colors.grey),
                            tooltip: 'Server Settings',
                            onPressed: _showServerConfig,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        langService.t('Grain Market ERP', 'غلہ منڈی ای آر پی'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F5132),
                        ),
                      ),
                      Text(
                        langService.t('Multi-Shop Mandi Manager & Khata ERP', 'ملٹی شاپ منڈی منیجر اور کھاتہ ای آر پی'),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: usernameCtrl,
                        decoration: InputDecoration(
                          labelText: langService.t('Username', 'یوزر نیم'),
                          prefixIcon: const Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isSignup) ...[
                        TextField(
                          controller: shopNameCtrl,
                          decoration: InputDecoration(
                            labelText: langService.t('Shop Name', 'دکان کا نام'),
                            prefixIcon: const Icon(Icons.store),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: ownerNameCtrl,
                          decoration: InputDecoration(
                            labelText: langService.t('Owner Name', 'مالک کا نام'),
                            prefixIcon: const Icon(Icons.badge),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: mobileCtrl,
                          decoration: InputDecoration(
                            labelText: langService.t('Mobile Number', 'موبائل نمبر'),
                            prefixIcon: const Icon(Icons.phone),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: cityCtrl,
                          decoration: InputDecoration(
                            labelText: langService.t('City', 'شہر'),
                            prefixIcon: const Icon(Icons.location_city),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: passwordCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: langService.t('Password', 'پاسورڈ'),
                          prefixIcon: const Icon(Icons.lock),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _submit,
                          child: isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(isSignup
                                  ? langService.t('Register Shop', 'رجسٹر کریں')
                                  : langService.t('Shopkeeper Login', 'لاگ ان کریں')),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => setState(() => isSignup = !isSignup),
                        child: Text(
                          isSignup
                              ? langService.t('Already have an account? Login', 'پہلے سے اکاؤنٹ ہے؟ لاگ ان کریں')
                              : langService.t('New Shopkeeper? Register Shop', 'نیا دوکاندار؟ رجسٹر کریں'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
