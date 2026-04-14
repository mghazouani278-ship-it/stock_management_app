import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_locale.dart';

const String _localeKey = 'app_locale';

class LocaleProvider with ChangeNotifier {
  // Par defaut, afficher l'UI en anglais.
  // L'utilisateur peut ensuite changer via LanguageSelector (et la preference est stockee).
  Locale _locale = const Locale('en');

  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';

  LocaleProvider() {
    ApiLocale.setLanguageCode(_locale.languageCode);
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_localeKey);
      if (code != null && (code == 'en' || code == 'ar')) {
        _locale = Locale(code);
        ApiLocale.setLanguageCode(code);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    ApiLocale.setLanguageCode(locale.languageCode);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, locale.languageCode);
    } catch (_) {}
  }

  Future<void> setEnglish() => setLocale(const Locale('en'));
  Future<void> setArabic() => setLocale(const Locale('ar'));
}
