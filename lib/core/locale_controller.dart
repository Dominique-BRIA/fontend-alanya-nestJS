import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contrôleur de langue pour Alanya.
/// Langue par défaut : français (fr)
/// Langues supportées : fr, en
class LocaleController extends ChangeNotifier {
  LocaleController();

  static const _prefsKey = 'alanya_locale';
  static const supportedLocales = ['fr', 'en'];

  Locale _locale = const Locale('fr');
  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;
  bool get isEnglish => _locale.languageCode == 'en';
  bool get isFrench => _locale.languageCode == 'fr';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey) ?? 'fr';
    if (supportedLocales.contains(code)) {
      _locale = Locale(code);
      notifyListeners();
    }
  }

  Future<void> setLocale(String code) async {
    if (!supportedLocales.contains(code)) return;
    if (_locale.languageCode == code) return;
    _locale = Locale(code);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, code);
  }

  Future<void> toggle() => setLocale(isFrench ? 'en' : 'fr');
}
