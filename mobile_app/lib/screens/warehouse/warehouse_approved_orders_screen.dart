import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/product_localized.dart';
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
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  String? _error;

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
        if (mounted) setState(() {
          _notifications = all.where((n) => n['type'] == 'order_approved').toList();
          _loading = false;
        });
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

  Future<void> _markAsRead() async {
    try {
      await _apiService.put('/order-notifications/read', {});
      if (mounted) _loadNotifications();
    } catch (_) {}
  }

  void _showDetails(Map<String, dynamic> notif) {
    final l10n = AppLocalizations.of(context)!;
    final productsRaw = notif['products'] ?? notif['Products'];
    final products = (productsRaw is List)
        ? productsRaw.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList()
        : <Map<String, dynamic>>[];
    final projectName = notif['projectName'] ?? notif['project_name'] ?? '—';
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
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.orderApprovedCreateDist,
                            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green, fontSize: 15),
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
                  child: Text(l10n.userLabel(userName.toString())),
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
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WarehouseDistributionFormScreen()),
                    ).then((_) => _loadNotifications());
                  },
                  icon: const Icon(Icons.local_shipping),
                  label: Text(l10n.createDistribution),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.orders),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.createDistribution,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WarehouseDistributionFormScreen()),
              ).then((_) => _loadNotifications());
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadNotifications,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
    if (_loading && _notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _notifications.isEmpty) {
      return ConnectionErrorWidget(message: _error!, onRetry: _loadNotifications);
    }
    if (_notifications.isEmpty) {
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
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final n = _notifications[index];
          final productsRaw = n['products'] ?? n['Products'];
          final products = (productsRaw is List) ? productsRaw : [];
          final totalQty = products.fold<int>(0, (sum, p) => sum + ((p is Map ? p['quantity'] : null) as int? ?? 0));
          final projectName = n['projectName'] ?? n['project_name'] ?? l10n.order;
          final orderId = n['orderId'] ?? '';
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.withOpacity(0.2),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 24),
              ),
              title: Text(
                projectName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (orderId.isNotEmpty)
                    Text(l10n.orderNumberPrefix(orderId.substring(0, orderId.length > 8 ? 8 : orderId.length)), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text(
                    l10n.orderCardProductsSummary(products.length, totalQty),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDetails(n),
            ),
          );
        },
      ),
    );
  }
}
