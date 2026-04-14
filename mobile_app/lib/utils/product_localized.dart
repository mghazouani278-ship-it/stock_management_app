import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/stock.dart';
import '../providers/locale_provider.dart';

/// Product name (English) → Arabic **literal / transliteration** when `name_ar` is not set.
/// Prefer filling **name_ar** in the admin form or in the database for exact wording.
const _productNameArFallback = <String, String>{
  'biaxial geogrids': 'شبك باى اكسيل',
  'uniaxial geogrids': 'شبك يونى اكسيل',
  'uniaxial geogrid': 'شبك يونى اكسيل',
  't-soket': 'ماسورة حرف تى',
  't-socket': 'ماسورة حرف تى',
  'u-trap': 'ماسورة حرف يو',
  'caps': 'كابات',
  'cap': 'كاب',
  'connector': 'كونكتور',
  'connectors': 'كونكتورات',
  'fair-face blocks': 'بلوك فيرفيس',
  'fair face blocks': 'بلوك فيرفيس',
  'fairface blocks': 'بلوك فيرفيس',
  'fair-face bloks': 'بلوك فيرفيس',
  'fair face bloks': 'بلوك فيرفيس',
  'mountain-face blocks': 'بلوك وش جبل',
  'mountain face blocks': 'بلوك وش جبل',
  'mountain-face bloks': 'بلوك وش جبل',
  'mountain face bloks': 'بلوك وش جبل',
  'panels': 'بلاطات',
  'panel': 'بلاطة',
  'pipes': 'مواسير',
  'pipe': 'ماسورة',
  'geocell': 'جيوسيل',
  'geogrid': 'جيوجريد',
  'geogrids': 'جيوجريد',
  'blocks': 'بلوكس',
  'hollow blocks': 'هولو بلوكس',
  'fair face': 'فيرفيس',
  'mountain face': 'وش جبل',
};

/// English → Arabic fallbacks when Firestore has no `category_ar` / `available_colors_ar`.
const _categoryArFallback = <String, String>{
  'retaining wall system': 'نظام الجدران الاستنادية',
  'retaining-wall-system': 'نظام الجدران الاستنادية',
  'geocell': 'جيوسيل',
  'geogrid': 'جيوجريد',
  'geogrid mesh': 'جيوجريد',
  'mesh geogrid': 'جيوجريد',
  'geogrids': 'جيوجريد',
  'wall system': 'نظام جدراني',
  'other': 'أخرى',
};

/// Variant / color labels (stored lowercased in [Product.availableColors]).
const _variantArFallback = <String, String>{
  'piece': 'قطعة',
  'pieces': 'قطع',
  'grey': 'رمادي',
  'gray': 'رمادي',
  'beige': 'بيج',
  'white': 'أبيض',
  'black': 'أسود',
  'brown': 'بني',
  'red': 'أحمر',
  'blue': 'أزرق',
  'green': 'أخضر',
  'yellow': 'أصفر',
  'orange': 'برتقالي',
  'pink': 'وردي',
  'purple': 'بنفسجي',
  // Geogrid predefined (lowercase as stored)
  '50 r': '50 R',
  '60 r': '60 R',
  '70 r': '70 R',
  '95 r': '95 R',
  '125 r': '125 R',
  '145 r': '145 R',
  '160 r': '160 R',
  '420 r': '420 R',
  '430 r': '430 R',
  '450 r': '450 R',
  '460 r': '460 R',
  '470 r': '470 R',
  're 510': 'RE 510',
  're 520': 'RE 520',
  're 540': 'RE 540',
  're 560': 'RE 560',
  're 570': 'RE 570',
  're 580': 'RE 580',
  'ux 1400': 'UX 1400',
  'ux 1500': 'UX 1500',
  'ux 1600': 'UX 1600',
  'kn': 'كيلونيوتن',
};

const _unitArFallback = <String, String>{
  'piece': 'قطعة',
  'pieces': 'قطع',
  'kg': 'كجم',
  'm²': 'م²',
  'm2': 'م²',
  'm': 'م',
  'lm': 'م.طولي',
  'pc': 'قطعة',
  'pcs': 'قطع',
  'unit': 'وحدة',
};

bool _containsArabicScript(String s) => RegExp(r'[\u0600-\u06FF]').hasMatch(s);

Map<String, String> _inverseMapFirstWins(Map<String, String> forward) {
  final m = <String, String>{};
  for (final e in forward.entries) {
    m.putIfAbsent(e.value, () => e.key);
  }
  return m;
}

final Map<String, String> _productNameEnFromAr = _inverseMapFirstWins(_productNameArFallback);
final Map<String, String> _categoryEnFromAr = _inverseMapFirstWins(_categoryArFallback);
final Map<String, String> _variantEnFromAr = _inverseMapFirstWins(_variantArFallback);
final Map<String, String> _unitEnFromAr = _inverseMapFirstWins(_unitArFallback);

/// Renders `m2` / `cm2` / … as **m²** / **cm²** (Unicode U+00B2) for on-screen unit labels.
String _formatUnitSquaredSuffix(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return t;
  switch (t.toLowerCase()) {
    case 'm2':
      return 'm²';
    case 'cm2':
      return 'cm²';
    case 'mm2':
      return 'mm²';
    case 'km2':
      return 'km²';
    default:
      return raw;
  }
}

/// Unité brute (API, commandes, maps) → affichage (**m²** au lieu de **m2**).
/// Pour un [Product] chargé, préférer [ProductLocalized.displayUnit].
String formatRawUnitForDisplay(String? raw) {
  if (raw == null) return '';
  final t = raw.trim();
  if (t.isEmpty) return '';
  return _formatUnitSquaredSuffix(t);
}

/// Valeur saisie / affichée → stockage API (**m2**, pas **m²**), en réutilisant les clés [_unitArFallback].
String normalizeUnitForApi(String raw) {
  var t = raw.trim();
  if (t.isEmpty) return t;
  final fromAr = _lookupUnitEn(t);
  if (fromAr != null) t = fromAr;
  final fromArLo = _lookupUnitEn(t.toLowerCase());
  if (fromArLo != null) t = fromArLo;
  return t.replaceAll('\u00B2', '2').replaceAll('²', '2');
}

String _englishDisplayFromKey(String key) {
  return key.split(' ').map((w) {
    if (w.isEmpty) return w;
    return w.split('-').map((p) {
      if (p.isEmpty) return p;
      return '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}';
    }).join('-');
  }).join(' ');
}

String? _tryProductNameEnKeys(String k) {
  if (_productNameEnFromAr[k] != null) return _productNameEnFromAr[k];
  final hyphenAsSpace = k.replaceAll('-', ' ');
  if (_productNameEnFromAr[hyphenAsSpace] != null) {
    return _productNameEnFromAr[hyphenAsSpace];
  }
  final spaceAsHyphen = k.replaceAll(' ', '-');
  if (_productNameEnFromAr[spaceAsHyphen] != null) {
    return _productNameEnFromAr[spaceAsHyphen];
  }
  return null;
}

/// Arabic / literal stored name → English key from [_productNameArFallback] when possible.
String? _lookupProductNameEn(String nameStored) {
  final raw = nameStored.trim();
  if (raw.isEmpty) return null;
  final direct = _tryProductNameEnKeys(raw);
  if (direct != null) return direct;
  final seg = raw.split(RegExp(r'[(\[:\|]')).first.trim();
  if (seg.isNotEmpty && seg != raw) {
    final sub = _tryProductNameEnKeys(seg);
    if (sub != null) return sub;
  }
  return null;
}

String? _lookupCategoryEn(String value) {
  final t = value.trim();
  if (t.isEmpty) return null;
  if (_categoryEnFromAr.containsKey(t)) return _categoryEnFromAr[t];
  for (final e in _categoryArFallback.entries) {
    if (e.value == t) return e.key;
  }
  return null;
}

String? _lookupVariantEn(String token) {
  final s = token.trim();
  if (s.isEmpty) return null;
  final lower = s.toLowerCase();
  if (_variantEnFromAr.containsKey(s)) return _variantEnFromAr[s];
  if (_variantEnFromAr.containsKey(lower)) return _variantEnFromAr[lower];
  for (final e in _variantArFallback.entries) {
    if (e.value.toLowerCase() == lower || e.value == s) return e.key;
  }
  return null;
}

String? _lookupUnitEn(String unitRaw) {
  final t = unitRaw.trim();
  if (t.isEmpty) return null;
  final lower = t.toLowerCase();
  if (_unitEnFromAr.containsKey(t)) return _unitEnFromAr[t];
  if (_unitEnFromAr.containsKey(lower)) return _unitEnFromAr[lower];
  for (final e in _unitArFallback.entries) {
    if (e.value == t || e.value == lower) return e.key;
  }
  return null;
}

String _englishResolvedProductName({required String name, String? nameAr}) {
  final en = name.trim();
  final ar = nameAr?.trim();
  final enLit = _lookupProductNameEn(en);
  if (enLit != null) return _englishDisplayFromKey(enLit);
  if (en.isNotEmpty && !_containsArabicScript(en)) {
    return en;
  }
  if (en.isNotEmpty) {
    return en;
  }
  if (ar != null && ar.isNotEmpty) {
    final fromAr = _lookupProductNameEn(ar);
    if (fromAr != null) return _englishDisplayFromKey(fromAr);
    return ar;
  }
  return name;
}

bool _isAr(BuildContext context) {
  try {
    return Provider.of<LocaleProvider>(context, listen: false).isArabic;
  } catch (_) {
    return Localizations.localeOf(context).languageCode == 'ar';
  }
}

String _capitalizeDisplay(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

String _normalizeProductNameKey(String s) {
  var t = s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  t = t.replaceAll('bloks', 'blocks');
  return t;
}

String? _tryProductNameKeys(String k) {
  if (_productNameArFallback[k] != null) return _productNameArFallback[k];
  final hyphenAsSpace = k.replaceAll('-', ' ');
  if (_productNameArFallback[hyphenAsSpace] != null) {
    return _productNameArFallback[hyphenAsSpace];
  }
  final spaceAsHyphen = k.replaceAll(' ', '-');
  if (_productNameArFallback[spaceAsHyphen] != null) {
    return _productNameArFallback[spaceAsHyphen];
  }
  return null;
}

String? _lookupProductNameAr(String nameEn) {
  final k = _normalizeProductNameKey(nameEn);
  final direct = _tryProductNameKeys(k);
  if (direct != null) return direct;
  // "Biaxial Geogrids (50 R)" → part before ( or : or extra suffix
  final seg = k.split(RegExp(r'[(\[:\|]')).first.trim();
  if (seg.isNotEmpty && seg != k) {
    final sub = _tryProductNameKeys(seg);
    if (sub != null) return sub;
  }
  return null;
}

/// Raw API product name → localized literal (AR / EN) when a fallback exists.
String localizedApiProductName(BuildContext context, String? nameEn) {
  if (nameEn == null || nameEn.isEmpty) return nameEn ?? '';
  if (!_isAr(context)) {
    final lit = _lookupProductNameEn(nameEn);
    if (lit != null) return _englishDisplayFromKey(lit);
    return nameEn;
  }
  return _lookupProductNameAr(nameEn) ?? nameEn;
}

/// Same as [localizedApiProductName] for Arabic without [BuildContext] (sort, logs).
String arabicLiteralProductNameFromString(String nameEn) {
  final t = nameEn.trim();
  if (t.isEmpty) return t;
  return _lookupProductNameAr(t) ?? t;
}

/// English display string for search/sort when API may store Arabic literals.
String englishLiteralProductNameFromString(String nameRaw) {
  final t = nameRaw.trim();
  if (t.isEmpty) return t;
  final lit = _lookupProductNameEn(t);
  if (lit != null) return _englishDisplayFromKey(lit);
  return t;
}

/// Color / variant token (API) for subtitles and parentheses.
String localizedVariantOrColorLabel(BuildContext context, String raw) {
  final t = raw.trim();
  if (!_isAr(context)) {
    final en = _lookupVariantEn(t);
    if (en != null) return _capitalizeDisplay(en);
    return _capitalizeDisplay(t);
  }
  return _translateVariantPiece(t, null);
}

/// Order / supplementary API line: localized product name, or [productId] if no name.
String localizedOrderProductDisplayName(
  BuildContext context,
  String? nameEn,
  String productId,
) {
  if (nameEn != null && nameEn.trim().isNotEmpty) {
    return localizedApiProductName(context, nameEn);
  }
  return productId;
}

/// Search: matches [qLower] against raw name, Arabic literal, English literal, or id fallback.
bool productNameMatchesSearchQuery(
  String? nameEn,
  String? fallbackId,
  String qLower,
) {
  final raw = (nameEn ?? fallbackId ?? '').toLowerCase();
  if (raw.contains(qLower)) return true;
  if (nameEn != null && nameEn.trim().isNotEmpty) {
    if (arabicLiteralProductNameFromString(nameEn).toLowerCase().contains(qLower)) {
      return true;
    }
    if (englishLiteralProductNameFromString(nameEn).toLowerCase().contains(qLower)) {
      return true;
    }
  }
  return false;
}

String _normalizeCategoryKey(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ').replaceAll('-', ' ');

String? _lookupCategoryAr(String en) {
  final k = _normalizeCategoryKey(en);
  if (_categoryArFallback[k] != null) return _categoryArFallback[k];
  final compact = k.replaceAll(' ', '');
  for (final e in _categoryArFallback.entries) {
    if (e.key.replaceAll(' ', '').replaceAll('-', '') == compact) {
      return e.value;
    }
  }
  return null;
}

/// Translates one variant token or a comma-separated list (e.g. "grey, beige").
String _translateVariantPiece(String raw, String? alignedAr) {
  final trimmed = alignedAr?.trim();
  if (trimmed != null &&
      trimmed.isNotEmpty &&
      trimmed.toLowerCase() != raw.trim().toLowerCase()) {
    return trimmed;
  }
  final s = raw.trim();
  if (s.contains(',')) {
    return s
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .map((p) => _translateSingleVariant(p))
        .join('، ');
  }
  return _translateSingleVariant(s);
}

String _translateSingleVariant(String key) {
  final lower = key.toLowerCase();
  return _variantArFallback[lower] ?? _capitalizeDisplay(key);
}

/// Same rules as [ProductLocalized.displayName] for Arabic, without [BuildContext]
/// (search, sort, or non-widget code).
String arabicDisplayNameForProduct(Product p) {
  final ar = p.nameAr?.trim();
  final en = p.name.trim();
  if (ar != null &&
      ar.isNotEmpty &&
      ar.toLowerCase() != en.toLowerCase()) {
    return ar;
  }
  return _lookupProductNameAr(p.name) ?? p.name;
}

/// Same rules as [ProductLocalized.displayName] for English, without [BuildContext].
String englishDisplayNameForProduct(Product p) {
  return _englishResolvedProductName(name: p.name, nameAr: p.nameAr);
}

extension ProductLocalized on Product {
  String displayName(BuildContext context) {
    if (_isAr(context)) {
      final ar = nameAr?.trim();
      final en = name.trim();
      if (ar != null &&
          ar.isNotEmpty &&
          ar.toLowerCase() != en.toLowerCase()) {
        return ar;
      }
      final fallback = _lookupProductNameAr(name);
      if (fallback != null) return fallback;
      return name;
    }
    return _englishResolvedProductName(name: name, nameAr: nameAr);
  }

  String displayCategories(BuildContext context) {
    if (category.isEmpty) return '';
    if (!_isAr(context)) {
      final parts = <String>[];
      for (var i = 0; i < category.length; i++) {
        final en = category[i].trim();
        if (en.isEmpty) continue;
        final mapped = _lookupCategoryEn(en);
        if (mapped != null) {
          parts.add(_englishDisplayFromKey(mapped.replaceAll('-', ' ')));
        } else if (!_containsArabicScript(en)) {
          parts.add(en);
        } else if (categoryAr != null && i < categoryAr!.length) {
          final ar = categoryAr![i].trim();
          final fromAr = _lookupCategoryEn(ar);
          parts.add(fromAr != null ? _englishDisplayFromKey(fromAr.replaceAll('-', ' ')) : en);
        } else {
          parts.add(en);
        }
      }
      return parts.join(', ');
    }
    final parts = <String>[];
    for (var i = 0; i < category.length; i++) {
      final en = category[i].trim();
      String? ar;
      if (categoryAr != null && i < categoryAr!.length) {
        final t = categoryAr![i].trim();
        if (t.isNotEmpty && t.toLowerCase() != en.toLowerCase()) ar = t;
      }
      ar ??= _lookupCategoryAr(en);
      parts.add(ar ?? en);
    }
    return parts.join('، ');
  }

  String displayVariantTokens(BuildContext context) {
    if (availableColors.isEmpty) return '';
    if (!_isAr(context)) {
      return availableColors.map((c) {
        final t = c.trim();
        final en = _lookupVariantEn(t);
        if (en != null) return _capitalizeDisplay(en);
        return _capitalizeDisplay(t);
      }).join(', ');
    }
    final out = <String>[];
    for (var i = 0; i < availableColors.length; i++) {
      final key = availableColors[i].trim();
      String? ar;
      if (availableColorsAr != null && i < availableColorsAr!.length) {
        final t = availableColorsAr![i].trim();
        if (t.isNotEmpty && t.toLowerCase() != key.toLowerCase()) ar = t;
      }
      out.add(_translateVariantPiece(key, ar));
    }
    return out.join('، ');
  }

  String displayUnit(BuildContext context) {
    final u = unit.trim();
    if (u.isEmpty) return u;
    if (!_isAr(context)) {
      final en = _lookupUnitEn(u);
      return _formatUnitSquaredSuffix(en ?? u);
    }
    final mapped = _unitArFallback[u.toLowerCase()];
    return _formatUnitSquaredSuffix(mapped ?? u);
  }

  /// Single variant/color chip label (e.g. stock line or dropdown item).
  String displayOneColor(BuildContext context, String colorRaw) {
    final lower = colorRaw.toLowerCase();
    final idx = availableColors.indexWhere((c) => c.toLowerCase() == lower);
    if (_isAr(context)) {
      if (idx >= 0 && availableColorsAr != null && idx < availableColorsAr!.length) {
        final t = availableColorsAr![idx].trim();
        if (t.isNotEmpty && t.toLowerCase() != colorRaw.trim().toLowerCase()) {
          return t;
        }
      }
      return _translateVariantPiece(colorRaw, null);
    }
    final cr = colorRaw.trim();
    final en = _lookupVariantEn(cr);
    if (en != null) return _capitalizeDisplay(en);
    return _capitalizeDisplay(cr);
  }
}

extension StockProductLocalized on StockProduct {
  String displayName(BuildContext context) => toDisplayProduct().displayName(context);

  String displayUnit(BuildContext context) => toDisplayProduct().displayUnit(context);

  String displayCategories(BuildContext context) => toDisplayProduct().displayCategories(context);

  String titleWithOptionalColor(BuildContext context, String? color) {
    final p = toDisplayProduct();
    final n = p.displayName(context);
    if (color == null || color.isEmpty) return n;
    return '$n (${p.displayOneColor(context, color)})';
  }
}
