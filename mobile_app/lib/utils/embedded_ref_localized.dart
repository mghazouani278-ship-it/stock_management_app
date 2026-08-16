import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/distribution.dart';
import '../models/order.dart';
import '../models/return_model.dart';
import '../models/supplementary_request.dart';
import '../providers/locale_provider.dart';
import 'project_localized.dart';

bool _looksLikeStoreName(String name) {
  return RegExp(
    r'\b(store|warehouse|depot|مخزن|مستودع|متجر)\b',
    caseSensitive: false,
  ).hasMatch(name);
}

String arabicLiteralStoreName(String name) {
  final t = name.trim();
  if (t.isEmpty) return t;
  final lower = t.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  const map = {
    'store': 'متجر',
    'warehouse': 'مستودع',
    'depot': 'مستودع',
    'main store': 'المتجر الرئيسي',
    'main warehouse': 'المستودع الرئيسي',
    'main depot': 'المستودع الرئيسي',
  };
  final exact = map[lower];
  if (exact != null) return exact;
  final numbered = RegExp(
    r'^(store|warehouse|depot)\s*(\d+)$',
    caseSensitive: false,
  ).firstMatch(t);
  if (numbered != null) {
    final kind = numbered.group(1)!.toLowerCase();
    final n = numbered.group(2);
    final label = kind == 'store' ? 'متجر' : 'مستودع';
    return '$label $n';
  }
  var out = t;
  out = out.replaceAllMapped(RegExp(r'\bwarehouse\b', caseSensitive: false), (_) => 'مستودع');
  out = out.replaceAllMapped(RegExp(r'\bdepot\b', caseSensitive: false), (_) => 'مستودع');
  out = out.replaceAllMapped(RegExp(r'\bstore\b', caseSensitive: false), (_) => 'متجر');
  out = out.replaceAllMapped(RegExp(r'\bmain\b', caseSensitive: false), (_) => 'الرئيسي');
  return out.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Nom affiché pour une référence API `{ name, nameAr? }` selon la langue.
String embeddedRefDisplayName(BuildContext context, String name, String? nameAr) {
  final isAr = Provider.of<LocaleProvider>(context, listen: false).isArabic;
  if (isAr) {
    final ar = nameAr?.trim();
    if (ar != null && ar.isNotEmpty) return ar;
    if (_looksLikeStoreName(name)) return arabicLiteralStoreName(name);
    return arabicLiteralProjectName(name);
  }
  return name;
}

extension OrderRefLocalized on OrderRef {
  String displayName(BuildContext context) => localizedProjectName(context, name, nameAr: nameAr);
}

extension ReturnRefLocalized on ReturnRef {
  String displayName(BuildContext context) => localizedProjectName(context, name, nameAr: nameAr);
}

extension DistributionRefLocalized on DistributionRef {
  String displayName(BuildContext context) => embeddedRefDisplayName(context, name, nameAr);
}

extension SupplementaryRequestRefLocalized on SupplementaryRequestRef {
  String displayName(BuildContext context) => localizedProjectName(context, name, nameAr: nameAr);
}
