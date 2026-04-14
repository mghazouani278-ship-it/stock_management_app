import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/order.dart';
import '../../../services/api_service.dart';
import '../../../utils/embedded_ref_localized.dart';
import '../../../utils/product_localized.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/order_display.dart';
import '../../../widgets/connection_error_widget.dart';
import 'order_form_screen.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  final ApiService _apiService = ApiService();
  final _searchController = TextEditingController();
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;
  bool _searchVisible = false;

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
    final q = _searchController.text.toLowerCase().trim();
    if (q.isEmpty) return _orders;
    return _orders.where((o) {
      final matchStatus = o.status.toLowerCase().contains(q);
      final matchProject = (o.project?.name.toLowerCase().contains(q) ?? false) ||
          (o.project?.nameAr?.toLowerCase().contains(q) ?? false);
      final matchProducts =
          o.products.any((p) => productNameMatchesSearchQuery(p.name, p.product, q));
      final matchNotes = o.notes?.toLowerCase().contains(q) ?? false;
      final matchOrderDate = o.orderDate?.toLowerCase().contains(q) ?? false;
      return matchStatus || matchProject || matchProducts || matchNotes || matchOrderDate;
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

  void _showOrderDetails(Order order) {
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
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                order.project != null ? '${l10n.order} • ${order.project!.displayName(context)}' : l10n.order,
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              _buildStatusChip(context, order.status),
              if (order.project != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(l10n.projectLabel(order.project!.displayName(context))),
                ),
              if (order.orderDate != null && order.orderDate!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(l10n.orderDateValue(order.orderDate!)),
                ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String status) {
    final l10n = AppLocalizations.of(context)!;
    Color color;
    switch (status) {
      case 'approved':
      case 'completed':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }
    return Chip(
      label: Text(localizedOrderStatus(l10n, status), style: const TextStyle(fontSize: 12)),
      backgroundColor: color.withOpacity(0.2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searchVisible
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.searchOrdersHint,
                  hintStyle: TextStyle(color: AppTheme.textSecondary),
                  border: InputBorder.none,
                ),
                cursorColor: AppTheme.primary,
                onSubmitted: (_) => setState(() {}),
              )
            : Text(AppLocalizations.of(context)!.myOrders),
        actions: [
          IconButton(
            icon: Icon(_searchVisible ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _searchVisible = !_searchVisible;
                if (!_searchVisible) _searchController.clear();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadOrders,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const OrderFormScreen()),
          );
          if (added == true && mounted) _loadOrders();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _orders.isEmpty) {
      return ConnectionErrorWidget(message: _error!, onRetry: _loadOrders);
    }
    if (_orders.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noOrdersYetUser, textAlign: TextAlign.center));
    }
    final filtered = _filteredOrders;
    if (filtered.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noResultsFor(_searchController.text), textAlign: TextAlign.center));
    }
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final order = filtered[index];
          final l10n = AppLocalizations.of(context)!;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getStatusColor(order.status),
                child: Icon(order.status == 'approved' || order.status == 'completed' ? Icons.check : order.status == 'rejected' ? Icons.close : Icons.pending, color: Colors.white, size: 20),
              ),
              title: Text(
                order.project?.displayName(context) ?? l10n.order,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                localizedOrderStatus(l10n, order.status),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showOrderDetails(order),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}
