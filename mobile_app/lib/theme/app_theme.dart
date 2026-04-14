import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/locale_provider.dart';

/// 2026 Premium SaaS Design System
/// Clean, minimal, elegant with soft shadows and smooth animations
/// Supports Arabic (Tajawal font) and English (Inter font)
class AppTheme {
  AppTheme._();

  // ─── Color Palette ─────────────────────────────────────────────────────
  static const Color primary = Color(0xFF6366F1);      // Indigo - professional accent
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8FAFC);    // Slate 50
  static const Color surfaceVariant = Color(0xFFF1F5F9); // Slate 100
  static const Color textPrimary = Color(0xFF0F172A);   // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  static const Color textTertiary = Color(0xFF94A3B8);  // Slate 400
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  /// Logo / splash background (dark teal)
  static const Color logoBackground = Color(0xFF004D6B);

  // ─── Spacing ───────────────────────────────────────────────────────────
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;
  static const double space2xl = 48;

  // ─── Border Radius ──────────────────────────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radius2xl = 24;

  // ─── Shadows (soft, elegant) ────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
      spreadRadius: -2,
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.02),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  /// Glassmorphism blur for overlays
  static const double glassBlur = 12;

  /// Neo-morphism soft inner highlight
  static List<BoxShadow> get neoInnerHighlight => [
    BoxShadow(
      color: Colors.white.withOpacity(0.7),
      blurRadius: 0,
      offset: const Offset(-1, -1),
    ),
  ];

  static List<BoxShadow> get cardShadowHover => [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.06),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.03),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get inputShadow => [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.03),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  // ─── Theme Data ─────────────────────────────────────────────────────────
  static bool _isArabicUi(BuildContext context) {
    try {
      return Provider.of<LocaleProvider>(context, listen: false).isArabic;
    } catch (_) {
      return Localizations.localeOf(context).languageCode == 'ar';
    }
  }

  /// Use instead of [GoogleFonts.inter] so Arabic text renders on web (Inter has no Arabic glyphs).
  /// Tajawal when app language is Arabic, Inter otherwise.
  ///
  /// On Android/iOS, [GoogleFonts] loads fonts at runtime over the network; that can break
  /// rendering on some devices. Use system fonts there; keep Google Fonts on web only.
  static TextStyle appTextStyle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
  }) {
    if (!kIsWeb) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        decoration: decoration,
      );
    }
    final builder = _isArabicUi(context) ? GoogleFonts.tajawal : GoogleFonts.inter;
    return builder(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
    );
  }

  static TextStyle _systemThemeTextStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
    );
  }

  /// Returns theme with font appropriate for locale (Tajawal for Arabic, Inter for others)
  static ThemeData themeForLocale(Locale locale) {
    final isArabic = locale.languageCode == 'ar';
    if (!kIsWeb) {
      return _buildTheme(_systemThemeTextStyle);
    }
    final font = isArabic ? GoogleFonts.tajawal : GoogleFonts.inter;
    return _buildTheme(font);
  }

  static ThemeData get lightTheme => themeForLocale(const Locale('en'));

  static ThemeData _buildTheme(dynamic font) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: primaryLight.withOpacity(0.15),
        surface: surface,
        onSurface: textPrimary,
        surfaceContainerHighest: surfaceVariant,
        error: error,
        onError: Colors.white,
        outline: textTertiary.withOpacity(0.5),
      ),
      scaffoldBackgroundColor: background,
      fontFamily: font().fontFamily,
      textTheme: _textThemeFor(font),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: surface,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: font(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary, size: 24),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: spaceXl, vertical: spaceMd),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: font(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: spaceXl, vertical: spaceMd),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: font(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: spaceMd, vertical: spaceMd),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMd)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: textTertiary.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: error),
        ),
        labelStyle: font(color: textSecondary, fontSize: 14),
        hintStyle: font(color: textTertiary, fontSize: 14),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusXl)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        contentTextStyle: font(color: Colors.white),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radius2xl)),
        ),
      ),
    );
  }

  /// Error SnackBar: red background, white text (use for API / validation errors).
  static SnackBar snackBarError(String message) => SnackBar(
        backgroundColor: error,
        content: Text(message, style: const TextStyle(color: Colors.white)),
      );

  static TextTheme _textThemeFor(dynamic font) {
    return TextTheme(
      displayLarge: font(fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.5),
      displayMedium: font(fontSize: 28, fontWeight: FontWeight.w600, color: textPrimary),
      displaySmall: font(fontSize: 24, fontWeight: FontWeight.w600, color: textPrimary),
      headlineLarge: font(fontSize: 22, fontWeight: FontWeight.w600, color: textPrimary),
      headlineMedium: font(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
      headlineSmall: font(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
      titleLarge: font(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
      titleMedium: font(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
      titleSmall: font(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
      bodyLarge: font(fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary),
      bodyMedium: font(fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary),
      bodySmall: font(fontSize: 12, fontWeight: FontWeight.w400, color: textSecondary),
      labelLarge: font(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
    );
  }
}
