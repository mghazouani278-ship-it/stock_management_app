import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/order.dart';
import '../../../models/user.dart';
import '../../../models/store.dart';
import '../../../services/api_service.dart';
import '../../../utils/order_display.dart';
import '../../../widgets/app_search_bar.dart';
import '../../../widgets/connection_error_widget.dart';
import '../../../utils/embedded_ref_localized.dart';
import '../../../utils/store_localized.dart';
import '../../../utils/product_localized.dart';
import '../../../utils/l10n_ui_helpers.dart';
import '../../../utils/project_localized.dart';
import '../../user/orders/order_form_screen.dart';
class AdminOrdersListScreen extends StatefulWidget {
  const AdminOrdersListScreen({super.key});

  @override
  State<AdminOrdersListScreen> createState() => _AdminOrdersListScreenState();
}

class _AdminOrdersListScreenState extends State<AdminOrdersListScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<Order> _orders = [];
  List<Store> _stores = [];
  bool _loading = true;
  String? _error;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Order> get _filteredOrders {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _orders;
    return _orders.where((o) {
      final matchUser = (o.user?.name.toLowerCase().contains(q) ?? false) ||
          (o.user?.nameAr?.toLowerCase().contains(q) ?? false) ||
          (o.user?.email?.toLowerCase().contains(q) ?? false);
      final matchProject = (o.project?.name.toLowerCase().contains(q) ?? false) ||
          (o.project?.nameAr?.toLowerCase().contains(q) ?? false);
      final matchProducts =
          o.products.any((p) => productNameMatchesSearchQuery(p.name, p.product, q));
      return matchUser ||
          matchProject ||
          matchProducts ||
          o.status.toLowerCase().contains(q) ||
          (o.orderDate?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _apiService.get('/orders');
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _orders = (res['data'] as List)
              .map((e) => Order.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _approveOrder(Order order) async {
    if (_stores.isEmpty) {
      try {
        final res = await _apiService.get('/stores');
        if (res['success'] == true && res['data'] != null) {
          _stores = (res['data'] as List).map((e) => Store.fromJson(Map<String, dynamic>.from(e))).toList();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
        return;
      }
    }
    if (_stores.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.noStoresAvailable)));
      return;
    }
    String? storeId = _stores.first.id;
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.approveOrder),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.selectStoreToDeduct),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: storeId,
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.storeRequired, border: const OutlineInputBorder()),
                items: _stores.map((s) => DropdownMenuItem(value: s.id, child: Text(s.displayName(context)))).toList(),
                onChanged: (v) => setD(() => storeId = v),
              ),
              const SizedBox(height: 12),
              Text(AppLocalizations.of(context)!.stockDeductedFromStore, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)!.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppLocalizations.of(context)!.approve)),
          ],
        ),
      ),
    );
    if (approved != true || !mounted) return;
    try {
      await _apiService.put('/orders/${order.id}/status', {'status': 'approved', 'store': storeId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.orderApproved), backgroundColor: Colors.green));
        _loadOrders();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteOrder(Order order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteOrder),
        content: Text(
          order.status == 'approved' || order.status == 'completed'
              ? AppLocalizations.of(context)!.deleteOrderRestoreStock
              : AppLocalizations.of(context)!.deleteOrderSimple,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context)!.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: Text(AppLocalizations.of(context)!.delete)),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _apiService.delete('/orders/${order.id}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.orderDeleted), backgroundColor: Colors.green));
        _loadOrders();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    }
  }

  Future<void> _rejectOrder(Order order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.rejectOrder),
        content: Text(AppLocalizations.of(context)!.rejectOrderQuestion),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context)!.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: Text(AppLocalizations.of(context)!.reject)),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _apiService.put('/orders/${order.id}/status', {'status': 'rejected'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.orderRejected), backgroundColor: Colors.orange));
        _loadOrders();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    }
  }

  Future<void> _openNewOrder() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final res = await _apiService.get('/projects', queryParams: {'light': 'true'});
      if (!mounted) return;
      if (res['success'] != true || res['data'] == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.noProjects)));
        }
        return;
      }
      final raw = res['data'] as List;
      if (raw.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.noProjects)));
        return;
      }
      final projects = raw.map((e) => Project.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      String? selectedId = projects.first.id;
      if (!mounted) return;
      final pickedId = await showDialog<String>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(l10n.newOrder),
            content: DropdownButtonFormField<String>(
              value: selectedId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.project,
                border: const OutlineInputBorder(),
              ),
              items: projects
                  .map(
                    (p) => DropdownMenuItem<String>(
                      value: p.id,
                      child: Text(p.displayName(ctx)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setDialogState(() => selectedId = v),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, selectedId),
                child: Text(l10n.ok),
              ),
            ],
          ),
        ),
      );
      if (pickedId == null || pickedId.isEmpty || !mounted) return;
      final added = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => OrderFormScreen(projectId: pickedId)),
      );
      if (added == true && mounted) _loadOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDetails(Order order) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
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
              Text(
                order.project != null ? '${l10n.order} • ${order.project!.displayName(context)}' : l10n.order,
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(localizedOrderStatus(l10n, order.status), style: const TextStyle(fontSize: 12)),
                backgroundColor: (order.status == 'approved' || order.status == 'completed' ? Colors.green : order.status == 'rejected' ? Colors.red : Colors.orange).withOpacity(0.2),
              ),
              if (order.project != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(l10n.projectLabel(order.project!.displayName(context)))),
              if (order.user != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(l10n.userLabel(localizedDisplayUserName(ctx, order.user!.name, nameAr: order.user!.nameAr))),
                ),
              if (order.orderDate != null && order.orderDate!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(l10n.orderDateValue(order.orderDate!))),
              const SizedBox(height: 16),
              Text(l10n.productsLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              ...order.products.map((p) {
                    final unit = formatRawUnitForDisplay(p.unit);
                    final qtyText = p.supplementary
                        ? '${p.projectQuantity} ${l10n.orderQtyLabelProject} + ${p.supplementaryQuantity} ${l10n.orderQtyLabelSupplementary} = ${p.quantity} $unit'
                        : '${p.quantity} $unit';
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '  • ${localizedOrderProductDisplayName(ctx, p.name, p.product)}: $qtyText',
                            ),
                          ),
                          if (p.supplementary)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(start: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(l10n.supplementary, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange)),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
              if (order.notes != null && order.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.notesLabel(order.notes!)),
              ],
              if (order.status == 'pending') ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _approveOrder(order);
                        },
                        icon: const Icon(Icons.check_circle),
                        label: Text(l10n.approve),
                        style: FilledButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _rejectOrder(order);
                        },
                        icon: const Icon(Icons.cancel),
                        label: Text(l10n.reject),
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
              if (order.status == 'approved' ||
                  order.status == 'completed' ||
                  order.status == 'rejected') ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deleteOrder(order);
                    },
                    icon: const Icon(Icons.delete_outline, size: 20),
                    label: Text(l10n.deleteOrderLabel),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppSearchBar(
          title: AppLocalizations.of(context)!.orders,
          searchHint: AppLocalizations.of(context)!.searchOrdersHint,
          searchController: _searchController,
          showSearch: _showSearch,
        ),
        actions: [
          AppSearchBar.searchButton(context: context, showSearch: _showSearch, onToggleSearch: () {
            setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) _searchController.clear();
            });
          }),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _loadOrders),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _loading ? null : _openNewOrder,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _orders.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null && _orders.isEmpty) {
      return ConnectionErrorWidget(message: _error!, onRetry: _loadOrders);
    }
    if (_orders.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noOrders, textAlign: TextAlign.center));
    }
    final items = _filteredOrders;
    if (items.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context)!.noOrdersMatch, textAlign: TextAlign.center),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final o = items[index];
          final l10n = AppLocalizations.of(context)!;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: o.status == 'approved' || o.status == 'completed' ? Colors.green : o.status == 'rejected' ? Colors.red : Colors.orange,
                child: Icon(o.status == 'approved' || o.status == 'completed' ? Icons.check : o.status == 'rejected' ? Icons.close : Icons.pending, color: Colors.white, size: 20),
              ),
              title: Text(o.project?.displayName(context) ?? l10n.order, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(localizedOrderStatus(l10n, o.status)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDetails(o),
            ),
          );
        },
      ),
    );
  }
}
