import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/distribution.dart';
import '../models/order.dart';
import '../models/return_model.dart';
import '../models/supplementary_request.dart';
import '../providers/locale_provider.dart';

/// Nom affiché pour une référence API `{ name, nameAr? }` selon la langue.
String embeddedRefDisplayName(BuildContext context, String name, String? nameAr) {
  final isAr = Provider.of<LocaleProvider>(context, listen: false).isArabic;
  if (isAr) {
    final ar = nameAr?.trim();
    if (ar != null && ar.isNotEmpty) return ar;
  }
  return name;
}

extension OrderRefLocalized on OrderRef {
  String displayName(BuildContext context) => embeddedRefDisplayName(context, name, nameAr);
}

extension ReturnRefLocalized on ReturnRef {
  String displayName(BuildContext context) => embeddedRefDisplayName(context, name, nameAr);
}

extension DistributionRefLocalized on DistributionRef {
  String displayName(BuildContext context) => embeddedRefDisplayName(context, name, nameAr);
}

extension SupplementaryRequestRefLocalized on SupplementaryRequestRef {
  String displayName(BuildContext context) => embeddedRefDisplayName(context, name, nameAr);
}
