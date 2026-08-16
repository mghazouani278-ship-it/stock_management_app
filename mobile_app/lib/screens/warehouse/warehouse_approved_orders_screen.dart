import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/l10n_ui_helpers.dart';
import '../../utils/product_localized.dart';
import '../../utils/project_localized.dart';
import '../../widgets/connection_error_widget.dart';
import 'warehouse_distribution_form_screen.dart';

/// Warehouse view: approved orders with quantities for distribution
class WarehouseApprovedOrdersScreen extends StatefulWidget {
  const WarehouseApprovedOrdersScreen({super.key});

  @override
  State<WarehouseApprovedOrdersScreen> createState() => _WarehouseApprovedOrdersScreenState();
}

class _WarehouseApprovedOrdersScreenState extends State<WarehouseApprovedOrdersScreen> {
  final ApiService _apiService = ApiService();
  /// Unread `new_order` — red banners (same style as former admin view).
  List<Map<String, dynamic>> _newOrderNotifications = [];
  List<Map<String, dynamic>> _approvedNotifications = [];
  /// Order ids that already have a distribution / are completed.
  final Set<String> _distributedOrderIds = {};
  bool _loading = true;
  String? _error;

  static Color? _colorFromApi(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var s = hex.replaceFirst('#', '').trim();
    if (s.length == 6) s = 'FF$s';
    if (s.length != 8) return null;
    return Color(int.parse(s, radix: 16));
  }

  Widget _buildNewOrderBanner(Map<String, dynamic> n) {
    final l10n = AppLocalizations.of(context)!;
    final bg = _colorFromApi(n['bannerBackground']?.toString()) ?? const Color(0xFFC62828);
    final projectName = localizedProjectName(
      context,
      (n['projectName'] ?? n['project_name'] ?? '').toString(),
    );
    final userName = n['userName'] ?? n['user_name'];
    final productsRaw = n['products'] ?? n['Products'];
    final products = (productsRaw is List) ? productsRaw : [];
    final totalQty = products.fold<int>(0, (sum, p) => sum + ((p is Map ? p['quantity'] : null) as int? ?? 0));
    final orderId = n['orderId']?.toString() ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: bg.withOpacity(0.16),
          child: Icon(Icons.notifications_active, color: bg, size: 22),
        ),
        title: Text(
          projectName.isNotEmpty ? projectName : '—',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.newOrder,
              style: TextStyle(fontSize: 12, color: bg, fontWeight: FontWeight.w600),
            ),
            if (userName != null && userName.toString().isNotEmpty)
              Text(
                l10n.userLabel(localizedDisplayUserName(context, userName.toString())),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            if (orderId.isNotEmpty)
              Text(
                l10n.orderNumberPrefix(orderId.substring(0, orderId.length > 8 ? 8 : orderId.length)),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            if (products.isNotEmpty)
              Text(
                l10n.orderCardProductsSummary(products.length, totalQty),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: bg),
        onTap: () => _showDetails(n),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _apiService.get('/order-notifications');
      if (res['success'] == true && res['data'] != null) {
        final all = (res['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final approved = <Map<String, dynamic>>[];
        final newUnread = <Map<String, dynamic>>[];
        final approvedOrderIds = <String>{};
        for (final n in all) {
          if (n['type'] == 'order_approved') {
            approved.add(n);
            final oid = n['orderId']?.toString() ?? '';
            if (oid.isNotEmpty) approvedOrderIds.add(oid);
          }
        }
        for (final n in all) {
          final t = n['type'];
          if (t == 'new_order') {
            final rd = n['read'];
            final oid = n['orderId']?.toString() ?? '';
            // Hide "New Order" once manager already approved the same order.
            if (rd != true && rd != 'true' && (oid.isEmpty || !approvedOrderIds.contains(oid))) {
              newUnread.add(n);
            }
          }
        }
        if (mounted) setState(() {
          _approvedNotifications = approved;
          _newOrderNotifications = newUnread;
          _loading = false;
        });
        await _refreshDistributedOrderIds(approved);
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _refreshDistributedOrderIds(List<Map<String, dynamic>> approved) async {
    final ids = approved
        .map((n) => n['orderId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty) {
      if (mounted) setState(() => _distributedOrderIds.clear());
      return;
    }
    final distributed = <String>{};
    try {
      final res = await _apiService.get('/orders');
      if (res['success'] == true && res['data'] is List) {
        for (final raw in res['data'] as List) {
          if (raw is! Map) continue;
          final id = (raw['id'] ?? raw['_id'])?.toString() ?? '';
          if (!ids.contains(id)) continue;
          final st = raw['status']?.toString().toLowerCase() ?? '';
          if (st == 'completed') distributed.add(id);
        }
      }
    } catch (_) {
      // Fall back: check distributions per order when list fetch fails.
      for (final id in ids) {
        try {
          final dRes = await _apiService.get('/distributions', queryParams: {'order': id});
          if (dRes['success'] == true) {
            final c = dRes['count'];
            final has = (c is int && c > 0) || (dRes['data'] is List && (dRes['data'] as List).isNotEmpty);
            if (has) distributed.add(id);
          }
        } catch (_) {}
      }
    }
    if (mounted) setState(() {
      _distributedOrderIds
        ..clear()
        ..addAll(distributed);
    });
  }

  int _parseQty(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }

  List<Map<String, dynamic>> _productsFromOrderData(Map<String, dynamic> data) {
    final orderProductsRaw = data['products'];
    if (orderProductsRaw is! List) return <Map<String, dynamic>>[];
    final out = <Map<String, dynamic>>[];
    for (final e in orderProductsRaw) {
      if (e is! Map) continue;
      final p = Map<String, dynamic>.from(e);
      final prod = p['product'];
      final repl = p['replacementProduct'] ?? p['replacement_product'];
      String? productId;
      String? productName;
      String? unit;
      if (repl is Map && (p['isReplaced'] == true || p['is_replaced'] == true || p['replacementProductId'] != null)) {
        productId = (repl['id'] ?? repl['_id'])?.toString();
        productName = repl['name']?.toString();
        unit = repl['unit']?.toString();
      }
      if (productId == null && prod is Map) {
        productId = (prod['id'] ?? prod['_id'])?.toString();
        productName = prod['name']?.toString();
        unit = prod['unit']?.toString();
      } else if (productId == null && prod != null) {
        productId = prod.toString();
        productName = p['name']?.toString() ?? p['productName']?.toString();
      }
      out.add({
        'productId': productId,
        'productName': productName,
        'quantity': _parseQty(p['quantity']),
        'color': p['color'] ?? p['variant'],
        'unit': unit,
      });
    }
    return out;
  }

  Future<void> _markAsRead() async {
    try {
      await _apiService.put('/order-notifications/read', {});
      if (mounted) _loadNotifications();
    } catch (_) {}
  }

  Future<void> _showDetails(Map<String, dynamic> notif) async {
    final l10n = AppLocalizations.of(context)!;
    final orderId = notif['orderId']?.toString() ?? '';
    final productsRaw = notif['products'] ?? notif['Products'];
    List<Map<String, dynamic>> products = (productsRaw is List)
        ? productsRaw.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList()
        : <Map<String, dynamic>>[];
    var type = notif['type']?.toString() ?? '';
    var status = notif['status']?.toString().toLowerCase() ?? '';

    // Prefer products already on the green approved notification for this order.
    if (products.isEmpty && orderId.isNotEmpty) {
      for (final a in _approvedNotifications) {
        if (a['orderId']?.toString() != orderId) continue;
        final raw = a['products'] ?? a['Products'];
        if (raw is List && raw.isNotEmpty) {
          products = raw
              .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
              .toList();
          type = 'order_approved';
          status = 'approved';
          break;
        }
      }
    }

    // Always refresh from the order so warehouse sees manager approval immediately.
    if (orderId.isNotEmpty && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      try {
        final orderRes = await _apiService.get('/orders/$orderId');
        if (orderRes['success'] == true && orderRes['data'] != null) {
          final data = Map<String, dynamic>.from(orderRes['data'] as Map);
          final fromOrder = _productsFromOrderData(data);
          if (fromOrder.isNotEmpty) products = fromOrder;
          status = data['status']?.toString().toLowerCase() ?? status;
          if (status == 'approved' || status == 'completed') {
            type = 'order_approved';
          }
        }
      } catch (_) {
        // Keep notification payload if order fetch fails.
      } finally {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      }
    }
    if (!mounted) return;
    var alreadyHasDistribution = false;
    if (orderId.isNotEmpty) {
      try {
        final dRes = await _apiService.get('/distributions', queryParams: {'order': orderId});
        if (dRes['success'] == true) {
          final c = dRes['count'];
          if (c is int) {
            alreadyHasDistribution = c > 0;
          } else if (dRes['data'] is List) {
            alreadyHasDistribution = (dRes['data'] as List).isNotEmpty;
          }
        }
      } catch (_) {}
    }
    final canCreateDistribution =
        (type == 'order_approved' || status == 'approved' || status == 'completed') &&
        !alreadyHasDistribution;
    // Red while waiting for warehouse distribution; green once distributed.
    final isGreenState = alreadyHasDistribution;
    final projectName = localizedProjectName(
      context,
      (notif['projectName'] ?? notif['project_name'] ?? '').toString(),
    );
    final userName = notif['userName'] ?? notif['user_name'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isGreenState ? Colors.green.withOpacity(0.15) : const Color(0xFFC62828).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isGreenState ? Colors.green.withOpacity(0.5) : const Color(0xFFC62828).withOpacity(0.40)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isGreenState ? Icons.check_circle : Icons.pending_actions,
                          color: isGreenState ? Colors.green : const Color(0xFFC62828),
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            alreadyHasDistribution
                                ? 'Distribution already created for this order'
                                : (canCreateDistribution ? l10n.orderApprovedCreateDist : l10n.whenAdminApprovesOrderHint),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isGreenState ? Colors.green : const Color(0xFFC62828),
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.projectLabel(projectName.toString()),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
              if (userName != null && userName.toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(l10n.userLabel(localizedDisplayUserName(context, userName.toString()))),
                ),
              const SizedBox(height: 16),
              Text(l10n.approvedQuantities, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              if (products.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(l10n.noProductsLabel, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                )
              else
                ...products.map((p) {
                  final rawName = p['productName'] ?? p['product_name'];
                  final nameBase = rawName != null && rawName.toString().trim().isNotEmpty
                      ? localizedApiProductName(context, rawName.toString())
                      : localizedApiProductName(context, p['productId']?.toString() ?? l10n.product);
                  final qty = p['quantity'] ?? 0;
                  final color = p['color']?.toString();
                  final unit = formatRawUnitForDisplay(p['unit']?.toString());
                  final display = color != null && color.isNotEmpty
                      ? '$nameBase (${localizedVariantOrColorLabel(context, color)})'
                      : nameBase;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        const Text('  • ', style: TextStyle(fontWeight: FontWeight.w500)),
                        Expanded(child: Text(display, style: const TextStyle(fontWeight: FontWeight.w500))),
                        Text('$qty $unit', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: canCreateDistribution
                      ? () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => WarehouseDistributionFormScreen(orderId: orderId.isNotEmpty ? orderId : null)),
                          ).then((_) => _loadNotifications());
                        }
                      : null,
                  icon: const Icon(Icons.local_shipping),
                  label: Text(canCreateDistribution
                      ? l10n.createDistribution
                      : (alreadyHasDistribution ? 'Distribution already created' : l10n.whenAdminApprovesOrderHint)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        await _markAsRead();
        if (!context.mounted) return;
        Navigator.of(context).pop(result);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.orders),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _loadNotifications,
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
    final hasContent = _newOrderNotifications.isNotEmpty || _approvedNotifications.isNotEmpty;
    if (_loading && !hasContent) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && !hasContent) {
      return ConnectionErrorWidget(message: _error!, onRetry: _loadNotifications);
    }
    if (!hasContent) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              l10n.noApprovedOrdersToDistribute,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.whenAdminApprovesOrderHint,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._newOrderNotifications.map(_buildNewOrderBanner),
          if (_approvedNotifications.isEmpty && _newOrderNotifications.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                l10n.noApprovedOrdersToDistribute,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ),
          ],
          ..._approvedNotifications.map((n) {
            final productsRaw = n['products'] ?? n['Products'];
            final products = (productsRaw is List) ? productsRaw : [];
            final totalQty = products.fold<int>(0, (sum, p) => sum + ((p is Map ? p['quantity'] : null) as int? ?? 0));
            final projectNameRaw = (n['projectName'] ?? n['project_name'] ?? '').toString();
            final projectName = projectNameRaw.isEmpty
                ? l10n.order
                : localizedProjectName(context, projectNameRaw);
            final orderId = n['orderId']?.toString() ?? '';
            final isDistributed = orderId.isNotEmpty && _distributedOrderIds.contains(orderId);
            const red = Color(0xFFC62828);
            final accent = isDistributed ? Colors.green : red;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: isDistributed ? null : red.withOpacity(0.06),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: accent.withOpacity(0.2),
                  child: Icon(
                    isDistributed ? Icons.check_circle : Icons.pending_actions,
                    color: accent,
                    size: 24,
                  ),
                ),
                title: Text(
                  projectName,
                  style: TextStyle(fontWeight: FontWeight.bold, color: isDistributed ? null : red),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDistributed ? l10n.orderStatusCompleted : l10n.newOrder,
                      style: TextStyle(fontSize: 12, color: accent, fontWeight: FontWeight.w600),
                    ),
                    if (orderId.isNotEmpty)
                      Text(l10n.orderNumberPrefix(orderId.substring(0, orderId.length > 8 ? 8 : orderId.length)), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    Text(
                      l10n.orderCardProductsSummary(products.length, totalQty),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                trailing: Icon(Icons.chevron_right, color: accent),
                onTap: () => _showDetails(n),
              ),
            );
          }),
        ],
      ),
    );
  }
}
