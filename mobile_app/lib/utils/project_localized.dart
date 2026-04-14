import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/locale_provider.dart';

/// English → Arabic literal when the API has no `name_ar` / localized fields.
const _projectNameArFallback = <String, String>{
  // add stable display names here when needed
};

const _ownerArFallback = <String, String>{
  'egypt grid': 'مصر للمقاولات',
};

bool _isAr(BuildContext context) {
  try {
    return Provider.of<LocaleProvider>(context, listen: false).isArabic;
  } catch (_) {
    return Localizations.localeOf(context).languageCode == 'ar';
  }
}

String _titleCaseWords(String lowerSpaced) {
  return lowerSpaced
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// Literal Arabic for project title when stored name is English-only.
String arabicLiteralProjectName(String nameEn) {
  final t = nameEn.trim();
  if (t.isEmpty) return t;
  final lower = t.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  final mapped = _projectNameArFallback[lower];
  if (mapped != null) return mapped;
  final m = RegExp(r'^project\s*(\d+)\s*$', caseSensitive: false).firstMatch(t);
  if (m != null) return 'مشروع ${m.group(1)}';
  final m2 = RegExp(r'^proj\.?\s*(\d+)\s*$', caseSensitive: false).firstMatch(t);
  if (m2 != null) return 'مشروع ${m2.group(1)}';
  final m3 = RegExp(r'^(\d+)\s+project\s*$', caseSensitive: false).firstMatch(t);
  if (m3 != null) return 'مشروع ${m3.group(1)}';
  return t;
}

/// English display when the API stores Arabic (or AR literals) but UI locale is EN.
String englishLiteralProjectName(String name) {
  final t = name.trim();
  if (t.isEmpty) return t;
  final m = RegExp(r'^مشروع\s*(\d+)\s*$').firstMatch(t);
  if (m != null) return 'Project ${m.group(1)}';
  final mEn = RegExp(r'^(\d+)\s+project\s*$', caseSensitive: false).firstMatch(t);
  if (mEn != null) return 'Project ${mEn.group(1)}';
  for (final e in _projectNameArFallback.entries) {
    if (e.value == t) {
      return _titleCaseWords(e.key);
    }
  }
  return t;
}

/// Literal Arabic for description placeholders (desc, desc1, xx, …).
String arabicLiteralProjectDescription(String desc) {
  final t = desc.trim();
  if (t.isEmpty) return t;
  final lower = t.toLowerCase();
  if (lower == 'xx' || lower == 'n/a' || lower == '—' || lower == '-') {
    return 'غير محدد';
  }
  if (lower == 'desc') return 'وصف';
  final dm = RegExp(r'^desc\s*(\d*)\s*$', caseSensitive: false).firstMatch(t);
  if (dm != null) {
    final n = dm.group(1);
    if (n == null || n.isEmpty) return 'وصف';
    return 'وصف $n';
  }
  return t;
}

/// Literal Arabic for owner / company names when not stored in Arabic.
String arabicLiteralProjectOwner(String owner) {
  final t = owner.trim();
  if (t.isEmpty) return t;
  final lower = t.toLowerCase();
  return _ownerArFallback[lower] ?? t;
}

/// English display when owner text is stored as Arabic literal.
String englishLiteralProjectOwner(String owner) {
  final t = owner.trim();
  if (t.isEmpty) return t;
  for (final e in _ownerArFallback.entries) {
    if (e.value == t) {
      return _titleCaseWords(e.key);
    }
  }
  return t;
}

/// English display for descriptions stored as Arabic literals.
String? englishLiteralProjectDescription(String? description) {
  if (description == null || description.trim().isEmpty) return null;
  final d = description.trim();
  if (d == 'غير محدد') return 'N/A';
  if (d == 'وصف') return 'desc';
  final dm = RegExp(r'^وصف\s*(\d*)\s*$').firstMatch(d);
  if (dm != null) {
    final n = dm.group(1);
    if (n == null || n.isEmpty) return 'desc';
    return 'desc $n';
  }
  return d;
}

String arabicDisplayNameForProject(Project p) {
  final ar = p.nameAr?.trim();
  if (ar != null && ar.isNotEmpty) return ar;
  return arabicLiteralProjectName(p.name);
}

String englishDisplayNameForProject(Project p) => englishLiteralProjectName(p.name);

extension ProjectLocalized on Project {
  String displayName(BuildContext context) {
    if (!_isAr(context)) return englishDisplayNameForProject(this);
    return arabicDisplayNameForProject(this);
  }

  String? displayDescription(BuildContext context) {
    final d = description;
    if (d == null || d.trim().isEmpty) return null;
    if (!_isAr(context)) return englishLiteralProjectDescription(d);
    return arabicLiteralProjectDescription(d);
  }

  String? displayOwner(BuildContext context) {
    final ar = projectOwnerAr?.trim();
    final en = projectOwner?.trim();
    if (_isAr(context)) {
      if (ar != null && ar.isNotEmpty) return ar;
      if (en != null && en.isNotEmpty) return arabicLiteralProjectOwner(en);
      return null;
    }
    if (en != null && en.isNotEmpty) return englishLiteralProjectOwner(en);
    if (ar != null && ar.isNotEmpty) return ar;
    return null;
  }
}

bool projectMatchesSearchQuery(Project p, String qLower, BuildContext context) {
  if (qLower.isEmpty) return true;
  if (p.name.toLowerCase().contains(qLower)) return true;
  if (p.nameAr != null && p.nameAr!.toLowerCase().contains(qLower)) return true;
  if (p.description?.toLowerCase().contains(qLower) ?? false) return true;
  if (p.projectOwner?.toLowerCase().contains(qLower) ?? false) return true;
  if (p.projectOwnerAr?.toLowerCase().contains(qLower) ?? false) return true;
  if (!_isAr(context)) {
    if (englishLiteralProjectName(p.name).toLowerCase().contains(qLower)) return true;
    if (p.description != null && p.description!.trim().isNotEmpty) {
      final enDesc = englishLiteralProjectDescription(p.description!);
      if (enDesc != null && enDesc.toLowerCase().contains(qLower)) return true;
    }
    if (p.projectOwner != null && p.projectOwner!.trim().isNotEmpty) {
      if (englishLiteralProjectOwner(p.projectOwner!).toLowerCase().contains(qLower)) {
        return true;
      }
    }
    if (p.projectOwnerAr != null && p.projectOwnerAr!.trim().isNotEmpty) {
      if (p.projectOwnerAr!.toLowerCase().contains(qLower)) return true;
    }
    return false;
  }
  if (arabicLiteralProjectName(p.name).toLowerCase().contains(qLower)) return true;
  if (p.description != null && p.description!.trim().isNotEmpty) {
    if (arabicLiteralProjectDescription(p.description!).toLowerCase().contains(qLower)) {
      return true;
    }
  }
  if (p.projectOwner != null && p.projectOwner!.trim().isNotEmpty) {
    if (arabicLiteralProjectOwner(p.projectOwner!).toLowerCase().contains(qLower)) {
      return true;
    }
  }
  return false;
}
