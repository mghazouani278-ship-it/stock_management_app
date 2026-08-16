import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/order.dart';
import '../../../models/stock.dart';
import '../../../models/user.dart';
import '../../../models/store.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../utils/order_display.dart';
import '../../../utils/roles.dart';
import '../../../widgets/app_search_bar.dart';
import '../../../widgets/connection_error_widget.dart';
import '../../../utils/embedded_ref_localized.dart';
import '../../../utils/store_localized.dart';
import '../../../utils/product_localized.dart';
import '../../../utils/l10n_ui_helpers.dart';
import '../../../utils/order_quantity_display.dart';
import '../../../utils/order_stock_store.dart';
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
  List<Map<String, dynamic>> _lateNotifications = [];
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

  Future<void> _loadLateNotifications() async {
    try {
      final res = await _apiService.get('/order-notifications');
      if (res['success'] == true && res['data'] is List) {
        final alerts = (res['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((n) =>
                (n['type'] == 'order_late' || n['type'] == 'order_arrived') &&
                n['read'] != true)
            .toList();
        if (mounted) setState(() => _lateNotifications = alerts);
        if (alerts.isNotEmpty) {
          try {
            await _apiService.put('/order-notifications/read', {});
          } catch (_) {}
        }
      }
    } catch (_) {}
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
      await _loadLateNotifications();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _approveOrder(Order order) async {
    final l10n = AppLocalizations.of(context)!;
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.noStoresAvailable)));
      return;
    }

    List<Stock> stocks = [];
    try {
      final stockRes = await _apiService.get('/stock');
      if (stockRes['success'] == true && stockRes['data'] != null) {
        stocks = (stockRes['data'] as List)
            .map((e) => Stock.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      return;
    }

    final lines = <Map<String, dynamic>>[];
    for (final p in order.products) {
      final color = p.color;
      final stock = findStockForOrderLine(stocks, p.product, color);
      final storeId = stock?.documentStoreId ?? stock?.store?.id;
      if (storeId == null || storeId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.productNoStockSelectStore), backgroundColor: Colors.orange),
          );
        }
        return;
      }
      lines.add({
        'productId': p.product,
        'name': localizedOrderProductDisplayName(context, p.name, p.product),
        'color': color,
        'qtyText': formatOrderProductQuantityText(l10n, p),
        'storeId': storeId,
      });
    }

    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.approveOrder),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...lines.map((line) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '• ${line['name']}: ${line['qtyText']}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.approve)),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    try {
      final productStores = lines.map((line) {
        final map = <String, dynamic>{
          'product': line['productId'],
          'store': line['storeId'],
        };
        final c = line['color'] as String?;
        if (c != null && c.isNotEmpty) map['color'] = c;
        return map;
      }).toList();
      await _apiService.put('/orders/${order.id}/status', {
        'status': 'approved',
        'productStores': productStores,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.orderApproved), backgroundColor: Colors.green));
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
      await _apiService.put('/orders/${order.id}/status', {'status': 'cancelled'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.orderRejected), backgroundColor: Colors.orange));
        _loadOrders();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    }
  }

  Future<void> _setOrderStatus(Order order, String status, {String? note}) async {
    if (status == 'pending_manager') {
      await _sendToManagerWithStockCheck(order);
      return;
    }
    try {
      final body = <String, dynamic>{'status': status};
      if (note != null && note.isNotEmpty) body['note'] = note;
      await _apiService.put('/orders/${order.id}/status', body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizedOrderStatus(AppLocalizations.of(context)!, status)), backgroundColor: Colors.green),
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
  }

  Future<List<Stock>> _loadAllStock() async {
    final stockRes = await _apiService.get('/stock');
    if (stockRes['success'] == true && stockRes['data'] != null) {
      return (stockRes['data'] as List)
          .map((e) => Stock.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  Map<String, dynamic> _orderProductToApiMap(OrderProduct p) {
    final map = <String, dynamic>{
      'product': p.product,
      'quantity': p.quantity,
      'original_product_id': p.originalProductId ?? p.product,
      'is_replaced': p.isReplaced,
      'projectQuantity': p.projectQuantity,
      'supplementaryQuantity': p.supplementaryQuantity,
      'supplementary': p.supplementary || p.supplementaryQuantity > 0,
    };
    if (p.color != null && p.color!.trim().isNotEmpty) {
      map['color'] = p.color!.trim().toLowerCase();
    }
    if (p.isReplaced) {
      map['replacement_product_id'] = p.replacementProductId ?? p.product;
      if (p.replacedAt != null) map['replaced_at'] = p.replacedAt;
    }
    return map;
  }

  Future<Order?> _replaceOrderProductLine({
    required Order order,
    required OrderProduct line,
    required List<Stock> stocks,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    if (!line.isReplaced) {
      final wantReplace = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        builder: (ctx) {
          final dl10n = AppLocalizations.of(ctx)!;
          return AlertDialog(
            title: Text('🔴 ${dl10n.outOfStock}'),
            content: Text(dl10n.insufficientStockReplacePrompt),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(false), child: Text(dl10n.cancel)),
              FilledButton(onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true), child: Text(dl10n.replaceProduct)),
            ],
          );
        },
      );
      if (wantReplace != true || !mounted) return null;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return null;
    }

    var stockList = stocks;
    if (stockList.isEmpty) {
      try {
        stockList = await _loadAllStock();
      } catch (_) {}
    }

    final originalId = line.originalProductId ?? line.product;
    final replacements = await _showOrderReplacementPicker(
      stocks: stockList,
      excludeProductId: originalId,
      requiredQuantity: line.quantity,
    );
    if (replacements == null || replacements.isEmpty || !mounted) return null;

    final productsPayload = <Map<String, dynamic>>[];
    for (final p in order.products) {
      final isSame = p.product == line.product && (p.color ?? '') == (line.color ?? '');
      if (!isSame) {
        productsPayload.add(_orderProductToApiMap(p));
        continue;
      }
      // Keep original project/supplementary split across replacement lines.
      var remainingProject = p.projectQuantity;
      var remainingSupp = p.supplementaryQuantity > 0
          ? p.supplementaryQuantity
          : (p.supplementary ? p.quantity : 0);
      if (remainingProject <= 0 && remainingSupp <= 0) {
        remainingProject = p.supplementary ? 0 : p.quantity;
        remainingSupp = p.supplementary ? p.quantity : 0;
      }
      for (final r in replacements) {
        final qty = r['quantity'] as int;
        if (qty <= 0) continue;
        final proj = qty < remainingProject ? qty : remainingProject;
        remainingProject -= proj;
        final supp = qty - proj;
        remainingSupp -= supp;
        productsPayload.add({
          'product': r['productId'],
          'quantity': qty,
          'original_product_id': originalId,
          'replacement_product_id': r['productId'],
          'is_replaced': true,
          'original_color': line.color,
          'projectQuantity': proj,
          'supplementaryQuantity': supp,
          'supplementary': supp > 0,
          if (r['color'] != null) 'color': r['color'],
        });
      }
    }

    try {
      final res = await _apiService.put('/orders/${order.id}', {
        'products': productsPayload,
        'sendToManager': false,
      });
      if (res['success'] == true && res['data'] != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.productReplacedSuccessfully), backgroundColor: Colors.green),
          );
        }
        return Order.fromJson(Map<String, dynamic>.from(res['data'] as Map));
      }
    } catch (e) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          useRootNavigator: true,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.replaceProduct),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(), child: Text(l10n.close)),
            ],
          ),
        );
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>?> _showOrderReplacementPicker({
    required List<Stock> stocks,
    required String excludeProductId,
    required int requiredQuantity,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    List<Stock> stockList = stocks;
    if (stockList.isEmpty) {
      try {
        stockList = await _loadAllStock();
      } catch (_) {}
    }

    final candidates = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final s in stockList) {
      final pid = (s.documentProductId ?? s.product?.id ?? '').trim();
      if (pid.isEmpty || pid == excludeProductId) continue;
      final variant = s.variant?.trim();
      final key = orderLineKey(pid, variant);
      if (seen.contains(key)) continue;
      final available = stockQuantityForOrderLine(stockList, pid, variant).floor();
      if (available <= 0) continue;
      seen.add(key);
      final rawName = s.product?.name ?? pid;
      String name;
      try {
        name = localizedApiProductName(context, rawName);
      } catch (_) {
        name = rawName;
      }
      String variantLabel = '';
      try {
        if (variant != null && variant.isNotEmpty) {
          variantLabel = localizedVariantOrColorLabel(context, variant);
        } else {
          final colors = s.product?.availableColors ?? const <String>[];
          if (colors.isNotEmpty) {
            variantLabel = colors
                .map((c) {
                  try {
                    return localizedVariantOrColorLabel(context, c);
                  } catch (_) {
                    return c;
                  }
                })
                .join(', ');
          }
        }
      } catch (_) {
        variantLabel = variant ?? '';
      }
      candidates.add({
        'productId': pid,
        'name': name,
        'variantLabel': variantLabel,
        'available': available,
        'unit': s.product?.unit?.toString() ?? '',
        'color': (variant != null && variant.isNotEmpty) ? variant.toLowerCase() : null,
      });
    }
    candidates.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    final totalAvailable = candidates.fold<int>(0, (sum, c) => sum + (c['available'] as int));
    if (candidates.isEmpty || totalAvailable < requiredQuantity) {
      if (!mounted) return null;
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: (ctx) {
          final dl10n = AppLocalizations.of(ctx)!;
          return AlertDialog(
            title: Text(dl10n.selectReplacementProduct),
            content: Text(
              candidates.isEmpty
                  ? dl10n.noProductsWithStock
                  : '${dl10n.noProductsWithStock}\n(${dl10n.quantity}: $requiredQuantity)',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(), child: Text(dl10n.close)),
            ],
          );
        },
      );
      return null;
    }

    final searchController = TextEditingController();
    final qtyControllers = <String, TextEditingController>{};
    for (final c in candidates) {
      final key = orderLineKey(c['productId'] as String, c['color'] as String?);
      qtyControllers[key] = TextEditingController(text: '0');
    }
    final selected = <String>{};

    try {
      return await showDialog<List<Map<String, dynamic>>>(
        context: context,
        useRootNavigator: true,
        builder: (ctx) {
          final dl10n = AppLocalizations.of(ctx)!;
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              int assigned = 0;
              for (final key in selected) {
                assigned += int.tryParse(qtyControllers[key]?.text.trim() ?? '') ?? 0;
              }
              final q = searchController.text.trim().toLowerCase();
              final filtered = q.isEmpty
                  ? candidates
                  : candidates.where((c) {
                      final name = (c['name'] as String).toLowerCase();
                      final variantText = (c['variantLabel'] as String? ?? '').toLowerCase();
                      return name.contains(q) || variantText.contains(q);
                    }).toList();
              return AlertDialog(
                title: Text(dl10n.selectReplacementProduct),
                content: SizedBox(
                  width: 460,
                  height: 480,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        dl10n.replacementAssignedQty('$assigned', '$requiredQuantity'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: assigned == requiredQuantity ? Colors.green[700] : Colors.orange[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          labelText: dl10n.searchProductsHint,
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(child: Text(dl10n.noProductsWithStock))
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final c = filtered[i];
                                  final key = orderLineKey(c['productId'] as String, c['color'] as String?);
                                  final available = c['available'] as int;
                                  final isOn = selected.contains(key);
                                  final qtyCtrl = qtyControllers[key]!;
                                  return CheckboxListTile(
                                    value: isOn,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(c['name'] as String, softWrap: true, maxLines: 2),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${dl10n.variant}: ${(c['variantLabel'] as String?)?.isNotEmpty == true ? c['variantLabel'] : '—'}\n'
                                          '${dl10n.availableQuantityLabel}: $available'
                                          '${(c['unit'] as String).isNotEmpty ? ' ${c['unit']}' : ''}',
                                        ),
                                        if (isOn) ...[
                                          const SizedBox(height: 8),
                                          TextField(
                                            controller: qtyCtrl,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              labelText: dl10n.quantity,
                                              hintText: dl10n.maxQtyHintNumber('$available'),
                                              border: const OutlineInputBorder(),
                                              isDense: true,
                                            ),
                                            onChanged: (_) => setDialogState(() {}),
                                          ),
                                        ],
                                      ],
                                    ),
                                    isThreeLine: true,
                                    onChanged: (v) {
                                      setDialogState(() {
                                        if (v == true) {
                                          selected.add(key);
                                          if ((int.tryParse(qtyCtrl.text) ?? 0) <= 0) {
                                            var otherAssigned = 0;
                                            for (final k in selected) {
                                              if (k == key) continue;
                                              otherAssigned += int.tryParse(qtyControllers[k]?.text.trim() ?? '') ?? 0;
                                            }
                                            final remaining = requiredQuantity - otherAssigned;
                                            final suggest = remaining > 0
                                                ? (remaining > available ? available : remaining)
                                                : 0;
                                            qtyCtrl.text = '$suggest';
                                          }
                                        } else {
                                          selected.remove(key);
                                          qtyCtrl.text = '0';
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
                    child: Text(dl10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () {
                      final result = <Map<String, dynamic>>[];
                      var sum = 0;
                      for (final c in candidates) {
                        final key = orderLineKey(c['productId'] as String, c['color'] as String?);
                        if (!selected.contains(key)) continue;
                        final qty = int.tryParse(qtyControllers[key]?.text.trim() ?? '') ?? 0;
                        final available = c['available'] as int;
                        if (qty <= 0) continue;
                        if (qty > available) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(dl10n.quantityExceedsMax('$available')), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        sum += qty;
                        result.add({
                          ...c,
                          'quantity': qty,
                        });
                      }
                      if (result.isEmpty || sum != requiredQuantity) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(dl10n.replacementQtyMustMatch('$requiredQuantity')),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      Navigator.of(ctx, rootNavigator: true).pop(result);
                    },
                    child: Text(dl10n.confirmReplacements),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      searchController.dispose();
      for (final c in qtyControllers.values) {
        c.dispose();
      }
    }
  }

  Future<void> _sendToManagerWithStockCheck(Order order) async {
    final l10n = AppLocalizations.of(context)!;
    List<Stock> stocks;
    try {
      stocks = await _loadAllStock();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
      return;
    }

    var current = order;
    for (final p in List<OrderProduct>.from(current.products)) {
      if (p.isReplaced) continue;
      final available = stockQuantityForOrderLine(stocks, p.product, p.color).floor();
      if (available >= p.quantity) continue;
      final updated = await _replaceOrderProductLine(order: current, line: p, stocks: stocks);
      if (updated == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.outOfStock), backgroundColor: Colors.orange),
          );
        }
        await _loadOrders();
        return;
      }
      current = updated;
    }

    try {
      await _apiService.put('/orders/${current.id}/status', {'status': 'pending_manager'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizedOrderStatus(l10n, 'pending_manager')), backgroundColor: Colors.green),
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
  }

  Future<void> _editPendingOrder(Order order) async {
    final l10n = AppLocalizations.of(context)!;
    final qtyControllers = <String, TextEditingController>{};
    for (final p in order.products) {
      final key = '${p.product}|${p.color ?? ''}';
      qtyControllers[key] = TextEditingController(text: '${p.quantity}');
    }
    final notesController = TextEditingController(text: order.notes ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editOrder),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...order.products.map((p) {
                  final key = '${p.product}|${p.color ?? ''}';
                  final name = localizedOrderProductDisplayName(ctx, p.name, p.product);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: qtyControllers[key],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: name,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  );
                }),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.notesOptional,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.save)),
        ],
      ),
    );
    if (saved != true || !mounted) {
      for (final c in qtyControllers.values) {
        c.dispose();
      }
      notesController.dispose();
      return;
    }
    try {
      final products = <Map<String, dynamic>>[];
      for (final p in order.products) {
        final key = '${p.product}|${p.color ?? ''}';
        final qty = int.tryParse(qtyControllers[key]?.text ?? '') ?? 0;
        if (qty <= 0) continue;
        final map = <String, dynamic>{'product': p.product, 'quantity': qty};
        if (p.color != null && p.color!.isNotEmpty) map['color'] = p.color;
        products.add(map);
      }
      if (products.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.addAtLeastOneProduct)));
        }
      } else {
        await _apiService.put('/orders/${order.id}', {
          'products': products,
          'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.orderUpdated), backgroundColor: Colors.green),
          );
          _loadOrders();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    } finally {
      for (final c in qtyControllers.values) {
        c.dispose();
      }
      notesController.dispose();
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

  Future<void> _showDetails(Order order) async {
    final l10n = AppLocalizations.of(context)!;
    final role = Provider.of<AuthProvider>(context, listen: false).user?.role;
    final canEditProducts = (isAdmin(role) && order.status == 'pending_admin')
        || (isManager(role) && order.status == 'pending_manager');
    List<Stock> stocks = [];
    if (canEditProducts) {
      try {
        stocks = await _loadAllStock();
      } catch (_) {}
    }
    if (!mounted) return;
    var currentOrder = order;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
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
                currentOrder.project != null ? '${l10n.order} • ${currentOrder.project!.displayName(context)}' : l10n.order,
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(localizedOrderStatus(l10n, currentOrder.status), style: const TextStyle(fontSize: 12)),
                backgroundColor: (currentOrder.status == 'approved' || currentOrder.status == 'completed' ? Colors.green : currentOrder.status == 'rejected' ? Colors.red : Colors.orange).withOpacity(0.2),
              ),
              if (currentOrder.project != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(l10n.projectLabel(currentOrder.project!.displayName(context)))),
              if (currentOrder.user != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(l10n.userLabel(localizedDisplayUserName(ctx, currentOrder.user!.name, nameAr: currentOrder.user!.nameAr))),
                ),
              if (currentOrder.orderDate != null && currentOrder.orderDate!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(l10n.orderDateValue(currentOrder.orderDate!))),
              if (currentOrder.displayArriveInDays != null)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text(l10n.expectedArrivalColumn(currentOrder.displayArriveInDays!))),
              if (currentOrder.distributionDate != null && currentOrder.distributionDate!.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text(l10n.orderDistributionDateValue(currentOrder.distributionDate!))),
              if (currentOrder.arrivalDate != null && currentOrder.arrivalDate!.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text(l10n.orderArrivalDateValue(currentOrder.arrivalDate!))),
              if (currentOrder.distributionDate == null &&
                  currentOrder.expectedArrivalDate != null &&
                  currentOrder.expectedArrivalDate!.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text(l10n.expectedArrivalDateValue(currentOrder.expectedArrivalDate!))),
              if (currentOrder.daysLate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(l10n.orderLateByDays(currentOrder.daysLate!), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                ),
              const SizedBox(height: 16),
              Text(l10n.productsLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              ...currentOrder.products.map((p) {
                    final qtyText = formatOrderProductQuantityText(l10n, p);
                    final shipId = p.isReplaced ? (p.replacementProductId ?? p.product) : p.product;
                    final available = canEditProducts ? stockQuantityForOrderLine(stocks, shipId, p.color).floor() : null;
                    final outOfStock = canEditProducts && available != null && available < p.quantity;
                    final displayName = p.isReplaced
                        ? (p.replacementProductName ?? localizedOrderProductDisplayName(ctx, p.name, p.product))
                        : localizedOrderProductDisplayName(ctx, p.name, p.product);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('  • $displayName: $qtyText'),
                          if (p.isReplaced) ...[
                            Text(
                              '    🟢 ${l10n.productReplacedSuccessfully}',
                              style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '    ${l10n.originalProduct}: ${p.originalProductName != null ? localizedApiProductName(ctx, p.originalProductName!) : (p.originalProductId ?? '')}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            ),
                            Text(
                              '    ${l10n.replacedByProduct}: ${p.replacementProductName != null ? localizedApiProductName(ctx, p.replacementProductName!) : displayName}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            ),
                          ],
                          if (outOfStock)
                            Text(
                              '    🔴 ${l10n.outOfStock}',
                              style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          if (canEditProducts)
                            TextButton.icon(
                              onPressed: () async {
                                final updated = await _replaceOrderProductLine(
                                  order: currentOrder,
                                  line: p,
                                  stocks: stocks,
                                );
                                if (updated != null) {
                                  setSheetState(() => currentOrder = updated);
                                  _loadOrders();
                                }
                              },
                              icon: const Icon(Icons.swap_horiz, size: 18),
                              label: Text(p.isReplaced ? l10n.changeReplacement : l10n.replaceProduct),
                            ),
                        ],
                      ),
                    );
                  }),
              if (currentOrder.notes != null && currentOrder.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.notesLabel(currentOrder.notes!)),
              ],
              if (currentOrder.status == 'pending' && isSupervisor(Provider.of<AuthProvider>(context, listen: false).user?.role)) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _editPendingOrder(currentOrder);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l10n.editOrder),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _setOrderStatus(currentOrder, 'pending_admin');
                        },
                        icon: const Icon(Icons.send),
                        label: Text(l10n.sendToAdmin),
                        style: FilledButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _setOrderStatus(currentOrder, 'returned');
                        },
                        icon: const Icon(Icons.undo),
                        label: Text(l10n.reject),
                        style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ],
              if (currentOrder.status == 'pending_admin' && isAdmin(Provider.of<AuthProvider>(context, listen: false).user?.role)) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _setOrderStatus(currentOrder, 'pending_manager');
                    },
                    icon: const Icon(Icons.send),
                    label: Text(l10n.sendToManager),
                    style: FilledButton.styleFrom(backgroundColor: Colors.blue),
                  ),
                ),
              ],
              if (currentOrder.status == 'pending_manager' && isManager(Provider.of<AuthProvider>(context, listen: false).user?.role)) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _approveOrder(currentOrder);
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
                          _rejectOrder(currentOrder);
                        },
                        icon: const Icon(Icons.cancel),
                        label: Text(l10n.reject),
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
              if (isManager(Provider.of<AuthProvider>(context, listen: false).user?.role) &&
                  (currentOrder.status == 'approved' ||
                      currentOrder.status == 'completed' ||
                      currentOrder.status == 'rejected' ||
                      currentOrder.status == 'cancelled')) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deleteOrder(currentOrder);
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
        itemCount: items.length + (_lateNotifications.isEmpty ? 0 : _lateNotifications.length + 1),
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
              final isArrived = n['type'] == 'order_arrived';
              final days = n['daysLate'] is int
                  ? n['daysLate'] as int
                  : int.tryParse('${n['daysLate']}') ?? 1;
              final rawProject = n['projectName']?.toString() ?? '';
              final projectName = rawProject.isEmpty
                  ? l10n.order
                  : localizedProjectName(context, rawProject);
              final userName = n['userName']?.toString();
              final bg = isArrived ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0);
              final accent = isArrived ? const Color(0xFF2E7D32) : const Color(0xFFE65100);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: bg,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: accent,
                    child: Icon(
                      isArrived ? Icons.check_circle : Icons.schedule,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(projectName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArrived ? l10n.orderArrivedNotification : l10n.orderLateByDays(days),
                        style: TextStyle(color: accent, fontWeight: FontWeight.w600),
                      ),
                      if (isArrived && userName != null && userName.isNotEmpty)
                        Text(
                          l10n.userLabel(localizedDisplayUserName(context, userName)),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
              );
            }
            index -= _lateNotifications.length + 1;
          }
          final o = items[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: o.status == 'approved' || o.status == 'completed' ? Colors.green : o.status == 'rejected' ? Colors.red : Colors.orange,
                child: Icon(o.status == 'approved' || o.status == 'completed' ? Icons.check : o.status == 'rejected' ? Icons.close : Icons.pending, color: Colors.white, size: 20),
              ),
              title: Text(o.project?.displayName(context) ?? l10n.order, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(localizedOrderStatus(l10n, o.status)),
                  if (o.displayArriveInDays != null)
                    Text(
                      o.daysLate != null
                          ? l10n.orderLateByDays(o.daysLate!)
                          : l10n.expectedArrivalColumn(o.displayArriveInDays!),
                      style: TextStyle(
                        fontSize: 12,
                        color: o.daysLate != null ? Colors.red : Colors.grey[600],
                        fontWeight: o.daysLate != null ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                ],
              ),
              isThreeLine: o.displayArriveInDays != null,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDetails(o),
            ),
          );
        },
      ),
    );
  }
}
