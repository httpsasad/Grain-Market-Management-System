import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ChangeNotifier {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  String _currentLang = 'en'; // Default language is English

  String get currentLang => _currentLang;
  bool get isUrdu => _currentLang == 'ur';

  Future<void> initLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLang = prefs.getString('app_language') ?? 'en';
    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    _currentLang = _currentLang == 'en' ? 'ur' : 'en';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', _currentLang);
    notifyListeners();
  }

  // Translation Helper
  String t(String enText, String urText) {
    return isUrdu ? urText : enText;
  }
}
