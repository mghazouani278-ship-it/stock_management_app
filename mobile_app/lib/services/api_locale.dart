/// Synced with [LocaleProvider] so API errors match the app language (Accept-Language).
class ApiLocale {
  ApiLocale._();

  static String languageCode = 'en';

  static void setLanguageCode(String code) {
    if (code == 'en' || code == 'ar') {
      languageCode = code;
    }
  }
}
