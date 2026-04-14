import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/return_model.dart';
import '../providers/locale_provider.dart';
import 'product_localized.dart';
import 'project_localized.dart';

bool _isArUi(BuildContext context) {
  try {
    return Provider.of<LocaleProvider>(context, listen: false).isArabic;
  } catch (_) {
    return Localizations.localeOf(context).languageCode == 'ar';
  }
}

/// Localizes return line condition (good / damaged).
String localizedReturnCondition(BuildContext context, String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final l10n = AppLocalizations.of(context)!;
  switch (raw.toLowerCase()) {
    case 'good':
      return l10n.goodCondition;
    case 'damaged':
      return l10n.damagedCondition;
    default:
      return raw;
  }
}

/// Localizes damaged-product reasons coming from API text values.
String localizedDamageReason(BuildContext context, String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final r = raw.trim().toLowerCase();
  final isAr = _isArUi(context);
  switch (r) {
    case 'returned as damaged':
      return isAr ? 'أُرجِع كـ تالف' : 'Returned as damaged';
    case 'damaged product from return':
      return isAr ? 'منتج تالف من مرتجع' : 'Damaged product from return';
    default:
      return raw;
  }
}

/// Project name on damaged-product screens (API → AR/EN literals).
String localizedDamagedProjectName(BuildContext context, String name) {
  if (_isArUi(context)) return arabicLiteralProjectName(name);
  return englishLiteralProjectName(name);
}

/// Store name when locale is AR (generic English tokens → Arabic).
String localizedDamagedStoreName(BuildContext context, String name) {
  if (!_isArUi(context)) return name;
  final raw = name.trim();
  final lettersOnly = raw.replaceAll(RegExp(r'[^A-Za-z]'), '').toLowerCase();
  if (lettersOnly == 'store') return 'متجر';
  if (lettersOnly == 'warehouse') return 'مستودع';
  if (lettersOnly == 'depot') return 'مستودع';
  return raw;
}

/// Notes often reuse the same English phrases as [localizedDamageReason].
String localizedDamagedNotes(BuildContext context, String? notes) {
  if (notes == null || notes.trim().isEmpty) return '';
  return localizedDamageReason(context, notes.trim());
}

/// Localizes common status strings for chips and subtitles.
String localizedUiStatus(BuildContext context, String raw) {
  final l10n = AppLocalizations.of(context)!;
  switch (raw.toLowerCase()) {
    case 'pending':
      return l10n.orderStatusPending;
    case 'approved':
      return l10n.approved;
    case 'rejected':
      return l10n.orderStatusRejected;
    case 'refused':
      return l10n.refused;
    case 'validated':
      return l10n.validatedStatus;
    case 'completed':
      return l10n.orderStatusCompleted;
    case 'active':
      return l10n.active;
    case 'inactive':
      return l10n.inactive;
    default:
      return raw;
  }
}

/// Display name for "administrator" system user.
String localizedApproverName(BuildContext context, String name) {
  final l = name.toLowerCase();
  if (l == 'administrator' || l == 'administrateur') {
    return AppLocalizations.of(context)!.administratorDisplayName;
  }
  return name;
}

/// API role (`user`, `admin`, `warehouse_user`, …) → localized label for lists and chips.
String localizedUserRole(BuildContext context, String role) {
  final l10n = AppLocalizations.of(context)!;
  final r = role.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '_');
  switch (r) {
    case 'admin':
      return l10n.roleAdmin;
    case 'user':
      return l10n.roleUser;
    case 'warehouse_user':
    case 'warehouse':
    case 'warehouseuser':
      return l10n.roleWarehouse;
    default:
      return role;
  }
}

/// Display name for list tiles when the stored name is a known English placeholder.
/// When UI is Arabic and [nameAr] is non-empty, shows the Arabic name.
String localizedDisplayUserName(BuildContext context, String name, {String? nameAr}) {
  if (_isArUi(context)) {
    final ar = nameAr?.trim();
    if (ar != null && ar.isNotEmpty) return ar;
  }
  final l = name.trim().toLowerCase();
  final l10n = AppLocalizations.of(context)!;
  if (l == 'administrator' || l == 'administrateur') {
    return l10n.administratorDisplayName;
  }
  if (l == 'warehouse user' || l == 'warehouse_user' || l == 'warehouseuser') {
    return l10n.roleWarehouse;
  }
  return name;
}

/// First character for avatar (handles Arabic display names).
String localizedUserAvatarLetter(BuildContext context, String name, {String? nameAr}) {
  final d = localizedDisplayUserName(context, name, nameAr: nameAr).trim();
  if (d.isEmpty) return '?';
  final it = d.runes.iterator;
  if (!it.moveNext()) return '?';
  return String.fromCharCode(it.current);
}

/// One line for a return product: bullet, name, optional variance (color), qty, condition.
String formatReturnProductLine(
  BuildContext context, {
  required String? productName,
  required int quantity,
  required String? condition,
  String? color,
  bool includeBullet = true,
}) {
  final l10n = AppLocalizations.of(context)!;
  final raw = productName?.trim();
  var n = (raw != null && raw.isNotEmpty)
      ? localizedApiProductName(context, raw)
      : l10n.product;
  if (color != null && color.trim().isNotEmpty) {
    n = '$n (${localizedVariantOrColorLabel(context, color.trim())})';
  }
  final cond = localizedReturnCondition(context, condition);
  final prefix = includeBullet ? '  • ' : '';
  return '$prefix$n ×$quantity ($cond)';
}

/// First line preview for list tiles (no bullet); optional "+N" when several products.
String formatReturnListPreview(BuildContext context, List<ReturnProduct> products) {
  if (products.isEmpty) return '';
  final p = products.first;
  final line = formatReturnProductLine(
    context,
    productName: p.productName,
    quantity: p.quantity,
    condition: p.condition,
    color: p.color,
    includeBullet: false,
  );
  if (products.length <= 1) return line;
  return '$line  (+${products.length - 1})';
}

/// JSON / API field key → localized label (reports, debug details).
String localizedReportFieldName(BuildContext context, String key) {
  final l10n = AppLocalizations.of(context)!;
  // Nettoyage plus robuste: enlève aussi ":" et autres séparateurs (ex: "User::", "Created at")
  final s = key.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  switch (s) {
    case 'name':
      return l10n.name;
    case 'email':
      return l10n.email;
    case 'password':
      return l10n.password;
    case 'status':
      return l10n.status;
    case 'quantity':
      return l10n.quantity;
    case 'notes':
      return l10n.reportFieldNotes;
    case 'description':
      return l10n.description;
    case 'reason':
      return l10n.reason;
    case 'unit':
      return l10n.unit;
    case 'category':
      return l10n.category;
    case 'color':
      return l10n.color;
    case 'manufacturer':
      return l10n.manufacturer;
    case 'distributor':
      return l10n.distributor;
    case 'project':
      return l10n.project;
    case 'store':
      return l10n.store;
    case 'user':
      return l10n.user;
    case 'order':
      return l10n.order;
    case 'product':
      return l10n.product;
    case 'products':
      return l10n.products;
    case 'productname':
      return l10n.reportFieldProduct;
    case 'productid':
      return l10n.reportFieldProductId;
    case 'projectid':
      return l10n.reportFieldProjectId;
    case 'storeid':
      return l10n.reportFieldStoreId;
    case 'userid':
      return l10n.reportFieldUserId;
    case 'orderid':
      return l10n.reportFieldOrderId;
    case 'returnid':
      return l10n.reportFieldReturnId;
    case 'distributionid':
      return l10n.reportFieldDistributionId;
    case 'createdat':
      return l10n.reportFieldCreatedAt;
    case 'updatedat':
      return l10n.reportFieldUpdatedAt;
    case 'approvedat':
      return l10n.reportFieldApprovedAt;
    case 'deliverydate':
      return l10n.reportFieldDeliveryDate;
    case 'distributiondate':
      return l10n.distributionDate;
    case 'validatedat':
      return l10n.validatedDate.replaceAll(':', '').trim();
    case 'serialnumber':
      return l10n.reportFieldSerialNumber;
    case 'bonalimentation':
      return l10n.reportFieldBonAlimentation;
    case 'materialrequest':
      return l10n.materialRequest;
    case 'phone':
      return l10n.reportFieldPhone;
    case 'address':
      return l10n.reportFieldAddress;
    case 'image':
      return l10n.reportFieldImage;
    case 'role':
      return l10n.reportFieldRole;
    case 'type':
      return l10n.reportFieldType;
    case 'condition':
      return l10n.reportFieldCondition;
    case 'extraquantity':
      return l10n.reportFieldExtraQuantity;
    case 'total':
      return l10n.reportFieldTotal;
    case 'price':
      return l10n.reportFieldPrice;
    case 'amount':
      return l10n.reportFieldAmount;
    case 'details':
      return l10n.reportFieldDetails;
    case 'title':
      return l10n.reportFieldTitle;
    case 'code':
      return l10n.reportFieldCode;
    case 'reference':
      return l10n.reportFieldReference;
    case 'approvedby':
      return l10n.reportFieldApprovedBy;
    case 'reportedby':
      return l10n.reportFieldReportedBy;
    case 'previousquantity':
      return l10n.reportFieldUnknown('previousQuantity');
    case 'newquantity':
      return l10n.reportFieldUnknown('newQuantity');
    case 'location':
      return l10n.location;
    case 'date':
      return l10n.reportFieldDate;
    case 'time':
      return l10n.reportFieldTime;
    case 'comment':
      return l10n.reportFieldComment;
    case 'priority':
      return l10n.reportFieldPriority;
    case 'source':
      return l10n.reportFieldSource;
    case 'destination':
      return l10n.reportFieldDestination;
    case 'value':
      return l10n.reportFieldValue;
    default:
      return l10n.reportFieldUnknown(key);
  }
}
