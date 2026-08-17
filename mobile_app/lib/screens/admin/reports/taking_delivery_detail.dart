import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/l10n_formatters.dart';
import '../../../utils/product_localized.dart';
import '../../../utils/project_localized.dart';
import '../../../utils/taking_delivery_pdf.dart';

/// Rich "Taking Delivery" detail sheet for one distribution (Reports).
Future<void> showTakingDeliveryDetails({
  required BuildContext context,
  required Map<String, dynamic> distribution,
}) async {
  final api = ApiService();
  final l10n = AppLocalizations.of(context)!;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  Map<String, dynamic>? project;
  Map<String, dynamic>? order;
  try {
    final projectId = distribution['project'] is Map
        ? distribution['project']['id']?.toString()
        : distribution['projectId']?.toString() ?? distribution['project_id']?.toString();
    final orderId = distribution['orderId']?.toString() ?? distribution['order_id']?.toString();
    if (projectId != null && projectId.isNotEmpty) {
      final res = await api.get('/projects/$projectId');
      if (res['success'] == true && res['data'] is Map) {
        project = Map<String, dynamic>.from(res['data'] as Map);
      }
    }
    if (orderId != null && orderId.isNotEmpty) {
      final res = await api.get('/orders/$orderId');
      if (res['success'] == true && res['data'] is Map) {
        order = Map<String, dynamic>.from(res['data'] as Map);
      }
    }
  } catch (_) {}

  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }
  if (!context.mounted) return;

  final payload = _buildPayload(context, l10n, distribution, project, order);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final dl10n = AppLocalizations.of(ctx)!;
      return DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radius2xl)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        dl10n.reportTakingDelivery,
                        style: AppTheme.appTextStyle(ctx, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: dl10n.procurementPrintPdf,
                      icon: const Icon(Icons.print_rounded),
                      onPressed: () => TakingDeliveryPdf.printReport(context: ctx, data: payload),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(AppTheme.spaceLg),
                  children: [
                    _sectionTitle(ctx, dl10n.project),
                    _kv(ctx, dl10n.takingDeliveryProjectCreated, payload['projectCreatedAt']?.toString() ?? '—'),
                    _kv(ctx, dl10n.project, payload['projectName']?.toString() ?? '—'),
                    _kv(ctx, dl10n.takingDeliveryProjectOwner, payload['projectOwner']?.toString() ?? '—'),
                    if ((payload['materialRequest'] ?? '').toString().isNotEmpty)
                      _kv(ctx, dl10n.materialRequest.replaceAll(':', '').trim(), payload['materialRequest'].toString()),
                    const SizedBox(height: 16),
                    _sectionTitle(ctx, dl10n.productsLabel),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowHeight: 36,
                        dataRowMinHeight: 36,
                        dataRowMaxHeight: 48,
                        columns: [
                          DataColumn(label: Text(dl10n.product, style: const TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text(dl10n.requestedQuantityLabel, style: const TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text(dl10n.takingDeliveryQtyDistributed, style: const TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text(dl10n.takingDeliveryQtyRemaining, style: const TextStyle(fontWeight: FontWeight.w700))),
                        ],
                        rows: ((payload['productRows'] as List?) ?? const []).map((r) {
                          final m = Map<String, dynamic>.from(r as Map);
                          return DataRow(cells: [
                            DataCell(Text('${m['name'] ?? ''}')),
                            DataCell(Text('${m['requested'] ?? 0}')),
                            DataCell(Text('${m['distributed'] ?? 0}')),
                            DataCell(Text('${m['remaining'] ?? 0}')),
                          ]);
                        }).toList(),
                      ),
                    ),
                    if (((payload['replacements'] as List?) ?? const []).isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionTitle(ctx, dl10n.takingDeliveryReplacements),
                      ...((payload['replacements'] as List).map((r) {
                        final m = Map<String, dynamic>.from(r as Map);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${dl10n.originalProduct}: ${m['original'] ?? ''}'),
                              Text('${dl10n.replacedByProduct}: ${m['replacement'] ?? ''}'),
                              if ((m['date'] ?? '').toString().isNotEmpty)
                                Text('${dl10n.replacementDate}: ${m['date']}'),
                            ],
                          ),
                        );
                      })),
                    ],
                    const SizedBox(height: 16),
                    _sectionTitle(ctx, dl10n.takingDeliveryTimeline),
                    ...((payload['timeline'] as List?) ?? const []).map((t) {
                      final m = Map<String, dynamic>.from(t as Map);
                      return _kv(ctx, '${m['label'] ?? ''}', '${m['date'] ?? '—'}');
                    }),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _sectionTitle(BuildContext context, String title) {
  return Text(title, style: AppTheme.appTextStyle(context, fontWeight: FontWeight.w700, fontSize: 15));
}

Widget _kv(BuildContext context, String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(label, style: AppTheme.appTextStyle(context, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, fontSize: 13)),
        ),
        Expanded(
          flex: 2,
          child: Text(value.isEmpty ? '—' : value, style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary, fontSize: 13)),
        ),
      ],
    ),
  );
}

String? _fmtDate(BuildContext context, dynamic raw) {
  if (raw == null) return null;
  return L10nFormatters.formatDateOnlyFromApi(context, raw)
      ?? L10nFormatters.formatDateFromApi(context, raw)
      ?? raw.toString().split('T').first;
}

Map<String, String?> _historyEvent(
  BuildContext context,
  List history,
  String toStatus, {
  List<String> preferRoles = const [],
}) {
  Map<String, String?>? preferred;
  Map<String, String?>? any;
  for (final h in history) {
    if (h is! Map) continue;
    final to = (h['toStatus'] ?? h['to_status'] ?? h['to'])?.toString();
    if (to != toStatus) continue;
    final name = (h['actorName'] ?? h['actor_name'] ?? h['byName'] ?? h['by'])?.toString();
    final role = (h['actorRole'] ?? h['actor_role'] ?? '').toString().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    final entry = <String, String?>{
      'date': _fmtDate(context, h['created_at'] ?? h['createdAt'] ?? h['at']),
      'name': (name != null && name.trim().isNotEmpty) ? name.trim() : null,
      'role': role,
    };
    any = entry;
    final roleOk = preferRoles.isEmpty ||
        preferRoles.any((r) => role == r || role.startsWith('${r}_') || role.contains(r));
    // Prefer real people over the generic "Administrator" system label when roles match.
    if (roleOk) {
      final n = (entry['name'] ?? '').toLowerCase();
      final isGenericAdmin = n == 'administrator' || n == 'administrateur';
      if (preferred == null || !isGenericAdmin) {
        preferred = entry;
      }
    }
  }
  return preferred ?? any ?? {'date': null, 'name': null};
}

String _personLabel(String? name, String eventLabel) {
  final n = (name ?? '').trim();
  if (n.isEmpty) return eventLabel;
  return '$n: $eventLabel';
}

String _arrivalLabel(String? userName, AppLocalizations l10n) {
  final n = (userName ?? '').trim();
  if (n.isEmpty) return l10n.takingDeliveryArrivedAtUser;
  return l10n.takingDeliveryArrivalAt(n);
}

String? _nameFromRef(dynamic ref) {
  if (ref is Map) {
    final n = ref['name']?.toString();
    if (n != null && n.trim().isNotEmpty) return n.trim();
  }
  return null;
}

Map<String, dynamic> _buildPayload(
  BuildContext context,
  AppLocalizations l10n,
  Map<String, dynamic> distribution,
  Map<String, dynamic>? project,
  Map<String, dynamic>? order,
) {
  final rawProjectName = project?['name']?.toString()
      ?? (distribution['project'] is Map ? distribution['project']['name']?.toString() : null)
      ?? '';
  final rawProjectNameAr = project?['nameAr']?.toString()
      ?? project?['name_ar']?.toString()
      ?? (distribution['project'] is Map
          ? (distribution['project']['nameAr'] ?? distribution['project']['name_ar'])?.toString()
          : null);
  final projectName = rawProjectName.isEmpty && (rawProjectNameAr == null || rawProjectNameAr.isEmpty)
      ? '—'
      : localizedProjectName(context, rawProjectName, nameAr: rawProjectNameAr);
  final rawOwner = project?['projectOwner']?.toString()
      ?? project?['project_owner']?.toString()
      ?? '';
  final rawOwnerAr = project?['projectOwnerAr']?.toString()
      ?? project?['project_owner_ar']?.toString();
  final projectOwner = rawOwner.isEmpty && (rawOwnerAr == null || rawOwnerAr.isEmpty)
      ? '—'
      : (Localizations.localeOf(context).languageCode == 'ar'
          ? ((rawOwnerAr != null && rawOwnerAr.trim().isNotEmpty)
              ? rawOwnerAr.trim()
              : arabicLiteralProjectOwner(rawOwner))
          : (rawOwner.isNotEmpty ? rawOwner : rawOwnerAr ?? '—'));
  final projectCreated = _fmtDate(context, project?['createdAt'] ?? project?['created_at']) ?? '—';

  final remainingByProduct = <String, int>{};
  final productsRaw = project?['products'];
  if (productsRaw is List) {
    for (final p in productsRaw) {
      if (p is! Map) continue;
      final prod = p['product'];
      final id = prod is Map ? (prod['id'] ?? prod['_id'])?.toString() : prod?.toString();
      if (id == null || id.isEmpty) continue;
      final rem = p['remainingQuantity'] ?? p['remaining_quantity'] ?? p['allowedQuantity'] ?? p['allowed_quantity'] ?? 0;
      final n = rem is num ? rem.toInt() : int.tryParse(rem.toString()) ?? 0;
      remainingByProduct[id] = n;
    }
  }

  final requestedById = <String, int>{};
  final requestedNameById = <String, String>{};
  final orderProducts = order?['products'];
  if (orderProducts is List) {
    for (final raw in orderProducts) {
      if (raw is! Map) continue;
      final prod = raw['product'];
      final id = prod is Map
          ? (prod['id'] ?? prod['_id'])?.toString()
          : (prod?.toString() ?? raw['product']?.toString());
      if (id == null || id.isEmpty) continue;
      final name = prod is Map
          ? (prod['name']?.toString() ?? id)
          : (raw['name']?.toString() ?? id);
      final qty = raw['quantity'] is num ? (raw['quantity'] as num).toInt() : int.tryParse('${raw['quantity']}') ?? 0;
      requestedById[id] = (requestedById[id] ?? 0) + qty;
      requestedNameById[id] = name;
    }
  }

  final productRows = <Map<String, dynamic>>[];
  final replacements = <Map<String, dynamic>>[];
  final seenIds = <String>{};
  final distProducts = distribution['products'];
  if (distProducts is List) {
    for (final raw in distProducts) {
      if (raw is! Map) continue;
      final p = Map<String, dynamic>.from(raw);
      final prod = p['product'];
      final shipId = prod is Map ? (prod['id'] ?? prod['_id'])?.toString() : prod?.toString();
      final shipName = prod is Map
          ? (prod['name']?.toString() ?? shipId ?? l10n.product)
          : (shipId ?? l10n.product);
      final originalId = (p['originalProductId'] ?? p['original_product_id'] ?? (p['originalProduct'] is Map ? p['originalProduct']['id'] : null))?.toString();
      final isReplaced = p['isReplaced'] == true || p['is_replaced'] == true;
      final displayName = localizedApiProductName(context, shipName);
      final qty = p['quantity'] is num ? (p['quantity'] as num).toInt() : int.tryParse('${p['quantity']}') ?? 0;
      final boqId = (isReplaced && originalId != null && originalId.isNotEmpty) ? originalId : (shipId ?? '');
      final requestKey = boqId.isNotEmpty ? boqId : (shipId ?? '');
      if (requestKey.isNotEmpty) seenIds.add(requestKey);
      if (shipId != null && shipId.isNotEmpty) seenIds.add(shipId);
      productRows.add({
        'name': displayName,
        'requested': requestedById[requestKey] ?? requestedById[shipId ?? ''] ?? qty,
        'distributed': qty,
        'remaining': remainingByProduct[boqId] ?? remainingByProduct[shipId ?? ''] ?? 0,
      });
      if (isReplaced) {
        final orig = p['originalProduct'] ?? p['original_product'];
        final repl = p['replacementProduct'] ?? p['replacement_product'] ?? prod;
        final origName = orig is Map ? (orig['name']?.toString() ?? originalId ?? '') : (originalId ?? '');
        final replName = repl is Map ? (repl['name']?.toString() ?? shipName) : shipName;
        replacements.add({
          'original': localizedApiProductName(context, origName.isEmpty ? l10n.product : origName),
          'replacement': localizedApiProductName(context, replName),
          'date': _fmtDate(context, p['replacedAt'] ?? p['replaced_at']) ?? '',
        });
      }
    }
  }
  for (final entry in requestedById.entries) {
    if (seenIds.contains(entry.key)) continue;
    productRows.add({
      'name': localizedApiProductName(context, requestedNameById[entry.key] ?? l10n.product),
      'requested': entry.value,
      'distributed': 0,
      'remaining': remainingByProduct[entry.key] ?? 0,
    });
  }

  final history = (order?['history'] is List) ? List.from(order!['history'] as List) : const [];
  final userName = _nameFromRef(order?['user']);
  final supervisorEvt = _historyEvent(
    context,
    history,
    'pending_admin',
    preferRoles: const ['supervisor'],
  );
  final adminEvt = _historyEvent(
    context,
    history,
    'pending_manager',
    preferRoles: const ['admin'],
  );
  final managerEvt = _historyEvent(
    context,
    history,
    'approved',
    preferRoles: const ['manager'],
  );
  final completedEvt = _historyEvent(context, history, 'completed');
  final warehouseName = _nameFromRef(distribution['createdBy'] ?? distribution['created_by']);

  final timeline = <Map<String, dynamic>>[
    {
      'label': _personLabel(userName, l10n.takingDeliveryUserOrderDate),
      'date': _fmtDate(context, order?['createdAt'] ?? order?['created_at'] ?? order?['orderDate']) ?? '—',
    },
    {
      'label': _personLabel(supervisorEvt['name'], l10n.takingDeliverySupervisorToAdmin),
      'date': supervisorEvt['date'] ?? '—',
    },
    {
      'label': _personLabel(adminEvt['name'], l10n.takingDeliveryAdminToManager),
      'date': adminEvt['date'] ?? '—',
    },
    {
      'label': _personLabel(managerEvt['name'], l10n.takingDeliveryManagerApproved),
      'date': _fmtDate(context, order?['approvedAt'] ?? order?['approved_at'])
          ?? managerEvt['date']
          ?? '—',
    },
    {
      'label': _personLabel(warehouseName, l10n.takingDeliveryWarehouseDistributed),
      'date': _fmtDate(context, distribution['distributionDate'] ?? distribution['createdAt'] ?? distribution['validatedAt']) ?? '—',
    },
    {
      'label': _arrivalLabel(userName, l10n),
      'date': _fmtDate(context, order?['deliveryDate'] ?? order?['delivery_date'])
          ?? completedEvt['date']
          ?? '—',
    },
  ];

  final mr = distribution['bonAlimentation'] ?? distribution['bon_alimentation'] ?? distribution['serialNumber'];

  return {
    'projectCreatedAt': projectCreated,
    'projectName': projectName,
    'projectOwner': projectOwner,
    'materialRequest': mr?.toString() ?? '',
    'productRows': productRows,
    'replacements': replacements,
    'timeline': timeline,
  };
}
