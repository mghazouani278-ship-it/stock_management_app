import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/order.dart';
import '../../../models/user.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../utils/embedded_ref_localized.dart';
import '../../../utils/product_localized.dart';
import '../../../utils/project_localized.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/order_display.dart';
import '../../../utils/order_quantity_display.dart';
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
  List<Map<String, dynamic>> _lateNotifications = [];
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

  Future<void> _loadLateNotifications() async {
    try {
      final res = await _apiService.get('/order-notifications');
      if (res['success'] == true && res['data'] is List) {
        final late = (res['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((n) => n['type'] == 'order_late' && n['read'] != true)
            .toList();
        if (mounted) setState(() => _lateNotifications = late);
        if (late.isNotEmpty) {
          try {
            await _apiService.put('/order-notifications/read', {});
          } catch (_) {}
        }
      }
    } catch (_) {}
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
      await _loadLateNotifications();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _openNewOrder() async {
    final l10n = AppLocalizations.of(context)!;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    var projects = List<Project>.from(auth.user?.projects ?? []);
    if (projects.isEmpty && auth.user?.project != null) {
      projects = [auth.user!.project!];
    }
    if (projects.isEmpty) {
      try {
        final res = await _apiService.get('/projects', queryParams: {'light': 'true'});
        if (!mounted) return;
        if (res['success'] == true && res['data'] is List) {
          projects = (res['data'] as List)
              .map((e) => Project.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      } catch (_) {}
    }
    if (!mounted) return;
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.noProjects)));
      return;
    }

    String? selectedId = projects.first.id;
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
              if (order.expectedArrivalDays != null || order.displayArriveInDays != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(l10n.expectedArrivalColumn(order.displayArriveInDays ?? order.expectedArrivalDays!)),
                ),
              if (order.distributionDate != null && order.distributionDate!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(l10n.orderDistributionDateValue(order.distributionDate!)),
                ),
              if (order.arrivalDate != null && order.arrivalDate!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(l10n.orderArrivalDateValue(order.arrivalDate!)),
                ),
              if (order.distributionDate == null &&
                  order.expectedArrivalDate != null &&
                  order.expectedArrivalDate!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(l10n.expectedArrivalDateValue(order.expectedArrivalDate!)),
                ),
              if (order.daysLate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.orderLateByDays(order.daysLate!),
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 16),
              Text(l10n.productsLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              ...order.products.map((p) {
                    final qtyText = formatOrderProductQuantityText(l10n, p);
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '  • ${localizedOrderProductDisplayName(ctx, p.name, p.product)}: $qtyText',
                      ),
                    );
                  }),
              if (order.notes != null && order.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.notesLabel(order.notes!)),
              ],
              if (order.status == 'returned') ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await _apiService.put('/orders/${order.id}/status', {'status': 'pending'});
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.orderResubmitted), backgroundColor: Colors.green),
                          );
                          _loadOrders();
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.send),
                    label: Text(l10n.resubmitToSupervisor),
                  ),
                ),
              ],
              if (order.status == 'completed' && !order.arrivalConfirmed) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await _apiService.put('/orders/${order.id}/confirm-arrival', {});
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.orderArrivedConfirmed),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _loadOrders();
                        }
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
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(l10n.confirmOrderArrived),
                    style: FilledButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ),
              ],
              if (order.status == 'completed' && order.arrivalConfirmed) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.orderArrivedSuccess,
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                ),
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
        onPressed: _openNewOrder,
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
        itemCount: filtered.length + (_lateNotifications.isEmpty ? 0 : _lateNotifications.length + 1),
        itemBuilder: (context, index) {
          final l10n = AppLocalizations.of(context)!;
          if (_lateNotifications.isNotEmpty) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(l10n.notifications, style: const TextStyle(fontWeight: FontWeight.w700)),
              );
            }
            if (index <= _lateNotifications.length) {
              final n = _lateNotifications[index - 1];
              final days = n['daysLate'] is int
                  ? n['daysLate'] as int
                  : int.tryParse('${n['daysLate']}') ?? 1;
              final projectName = localizedProjectName(
                context,
                n['projectName']?.toString() ?? '',
              );
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: const Color(0xFFFFF3E0),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE65100),
                    child: Icon(Icons.schedule, color: Colors.white, size: 20),
                  ),
                  title: Text(
                    projectName.isNotEmpty ? projectName : l10n.order,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    l10n.orderLateByDays(days),
                    style: const TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.w600),
                  ),
                ),
              );
            }
            index -= _lateNotifications.length + 1;
          }
          final order = filtered[index];
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
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizedOrderStatus(l10n, order.status),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (order.displayArriveInDays != null)
                    Text(
                      order.daysLate != null
                          ? l10n.orderLateByDays(order.daysLate!)
                          : l10n.expectedArrivalColumn(order.displayArriveInDays!),
                      style: TextStyle(
                        fontSize: 12,
                        color: order.daysLate != null ? Colors.red : Colors.grey[600],
                        fontWeight: order.daysLate != null ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                ],
              ),
              isThreeLine: order.displayArriveInDays != null,
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
      case 'cancelled':
        return Colors.red;
      case 'returned':
        return Colors.orange;
      case 'pending_admin':
      case 'pending_manager':
        return Colors.deepPurple;
      default:
        return Colors.blue;
    }
  }
}
