import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');
  static const String _prefKey = 'language';

  Locale get locale => _locale;
  bool get isRtl => _locale.languageCode == 'fa';

  LocaleProvider() {
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString(_prefKey) ?? 'en';
    _locale = Locale(langCode);
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, locale.languageCode);
    notifyListeners();
  }

  Future<void> toggleLocale() async {
    final newLocale = _locale.languageCode == 'en'
        ? const Locale('fa')
        : const Locale('en');
    await setLocale(newLocale);
  }
}
