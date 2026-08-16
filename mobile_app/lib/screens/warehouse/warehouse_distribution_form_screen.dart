import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/product_localized.dart';
import '../../../utils/project_localized.dart';
import '../../../utils/l10n_formatters.dart';
import '../../../utils/order_stock_store.dart';
import '../../../utils/roles.dart';
import '../../../models/stock.dart';
import '../../../models/store.dart';
import '../../../models/user.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/connection_error_widget.dart';
import 'warehouse_approved_orders_screen.dart';

class WarehouseDistributionFormScreen extends StatefulWidget {
  const WarehouseDistributionFormScreen({super.key, this.orderId});
  final String? orderId;

  @override
  State<WarehouseDistributionFormScreen> createState() => _WarehouseDistributionFormScreenState();
}

class _WarehouseDistributionFormScreenState extends State<WarehouseDistributionFormScreen> {
  final ApiService _apiService = ApiService();
  List<Project> _projects = [];
  List<Store> _depots = [];
  final _serialNumberController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedProjectId;
  /// Resolved automatically: approved order store, project [depotId], or first approved order for project.
  String? _resolvedStoreId;
  DateTime _distributionDate = DateTime.now();
  final List<Map<String, dynamic>> _selectedProducts = [];
  List<Stock> _locationStock = [];
  /// Order-level approved quantities keyed by **BOQ / original** product+variant.
  final Map<String, int> _orderApprovedQtyByKey = {};
  /// When an order line was replaced: BOQ key → ship product (replacement) info.
  final Map<String, Map<String, dynamic>> _orderShipByBoqKey = {};
  /// Stores from approved order (one per product line); empty = use [_resolvedStoreId] only.
  Set<String> _orderStoreIds = {};
  Map<String, String> _orderStoreByProductKey = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _serialNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _applyStoreFromOrderId(String oid) async {
    try {
      final res = await _apiService.get('/orders/${Uri.encodeComponent(oid)}');
      if (!mounted || res['success'] != true || res['data'] == null) return;
      final data = Map<String, dynamic>.from(res['data'] as Map);
      final sid = data['approvedStoreId']?.toString() ?? data['approved_store_id']?.toString();
      final approvedStores = data['approvedProductStores'] ?? data['approved_product_stores'];
      final Set<String> storeIds = {};
      final storeByKey = <String, String>{};
      if (approvedStores is List) {
        for (final raw in approvedStores) {
          if (raw is! Map) continue;
          final s = raw['store']?.toString() ?? raw['store_id']?.toString();
          final pid = raw['product']?.toString() ?? raw['product_id']?.toString();
          final color = raw['color']?.toString() ?? raw['variant']?.toString();
          if (s != null && s.isNotEmpty) storeIds.add(s);
          if (pid != null && pid.isNotEmpty && s != null && s.isNotEmpty) {
            storeByKey[orderLineKey(pid, color)] = s;
          }
        }
      }
      if (storeIds.isEmpty && sid != null && sid.isNotEmpty) storeIds.add(sid);
      final proj = data['project'];
      String? projectId = _selectedProjectId;
      if (proj is Map) {
        final pid = proj['id']?.toString();
        if (pid != null && pid.isNotEmpty) projectId = pid;
      }
      final orderApproved = <String, int>{};
      final orderShip = <String, Map<String, dynamic>>{};
      final prods = data['products'];
      if (prods is List) {
        for (final raw in prods) {
          if (raw is! Map) continue;
          final p = Map<String, dynamic>.from(raw);
          final shipId = _canonicalProductId(p['product']);
          if (shipId.isEmpty) continue;
          final originalId = _canonicalProductId(
            p['originalProductId'] ?? p['original_product_id'] ?? p['originalProduct'] ?? p['product'],
          );
          final replacementId = _canonicalProductId(
            p['replacementProductId'] ?? p['replacement_product_id'] ?? p['replacementProduct'],
          );
          final isReplaced = p['isReplaced'] == true ||
              p['is_replaced'] == true ||
              (replacementId.isNotEmpty && replacementId != originalId);
          final boqId = (isReplaced && originalId.isNotEmpty) ? originalId : shipId;
          final shipColor = p['color']?.toString() ?? p['variant']?.toString();
          final boqColor = isReplaced
              ? (p['originalColor'] ?? p['original_color'] ?? shipColor)?.toString()
              : shipColor;
          final key = _lineKey(boqId, boqColor);
          final qty = _parseQuantity(p['quantity']);
          if (qty <= 0) continue;
          orderApproved[key] = (orderApproved[key] ?? 0) + qty;
          if (isReplaced) {
            final shipPid = replacementId.isNotEmpty ? replacementId : shipId;
            final repl = p['replacementProduct'] ?? p['replacement_product'];
            final orig = p['originalProduct'] ?? p['original_product'];
            final shipName = repl is Map
                ? (repl['name']?.toString() ?? shipPid)
                : (p['name']?.toString() ?? shipPid);
            final originalName = orig is Map
                ? (orig['name']?.toString() ?? boqId)
                : boqId;
            final unit = repl is Map ? repl['unit']?.toString() : null;
            final prev = orderShip[key];
            final prevQty = _parseQuantity(prev?['quantity']);
            orderShip[key] = {
              'productId': shipPid,
              'color': shipColor,
              'name': shipName,
              'originalName': originalName,
              'unit': unit,
              'quantity': prevQty + qty,
            };
            // Stock lookup for the replacement should use the same approved store as the BOQ line.
            final storeForBoq = storeByKey[key] ?? storeByKey[_lineKey(boqId, boqColor)];
            if (storeForBoq != null && storeForBoq.isNotEmpty) {
              storeByKey[_lineKey(shipPid, shipColor)] = storeForBoq;
            }
          }
        }
      }
      setState(() {
        if (sid != null && sid.trim().isNotEmpty) _resolvedStoreId = sid.trim();
        if (projectId != null && projectId.trim().isNotEmpty) _selectedProjectId = projectId.trim();
        _orderApprovedQtyByKey
          ..clear()
          ..addAll(orderApproved);
        _orderShipByBoqKey
          ..clear()
          ..addAll(orderShip);
        _orderStoreIds = storeIds;
        _orderStoreByProductKey = storeByKey;
      });
      await _refreshLocationStock();
      if (mounted) _prefillSelectedFromOrder(data);
    } catch (_) {}
  }

  /// Prefill distribution lines from the approved order (including replacements).
  void _prefillSelectedFromOrder(Map<String, dynamic> data) {
    if (_selectedProducts.isNotEmpty) return;
    if (_selectedProjectId == null) return;
    final project = _projects.cast<Project?>().firstWhere(
          (p) => p?.id == _selectedProjectId,
          orElse: () => null,
        );
    if (project?.products == null) return;
    final prods = data['products'];
    if (prods is! List) return;
    for (final raw in prods) {
      if (raw is! Map) continue;
      final p = Map<String, dynamic>.from(raw);
      final shipId = _canonicalProductId(p['product']);
      if (shipId.isEmpty) continue;
      final qty = _parseQuantity(p['quantity']);
      if (qty <= 0) continue;
      final originalId = _canonicalProductId(
        p['originalProductId'] ?? p['original_product_id'] ?? p['originalProduct'] ?? p['product'],
      );
      final replacementId = _canonicalProductId(
        p['replacementProductId'] ?? p['replacement_product_id'] ?? p['replacementProduct'],
      );
      final isReplaced = p['isReplaced'] == true ||
          p['is_replaced'] == true ||
          (replacementId.isNotEmpty && replacementId != originalId);
      final boqId = (isReplaced && originalId.isNotEmpty) ? originalId : shipId;
      final shipColor = p['color']?.toString() ?? p['variant']?.toString();
      final boqColor = isReplaced
          ? (p['originalColor'] ?? p['original_color'] ?? shipColor)?.toString()
          : shipColor;
      final wantBoq = _normalizeVariant(boqColor);
      int? lineIndex;
      for (var i = 0; i < project!.products!.length; i++) {
        final pp = project.products![i];
        if (_canonicalProductId(pp.product) == boqId && _normalizeVariant(pp.color) == wantBoq) {
          lineIndex = i;
          break;
        }
      }
      final repl = p['replacementProduct'] ?? p['replacement_product'];
      final prod = p['product'];
      final orig = p['originalProduct'] ?? p['original_product'];
      final shipName = isReplaced && repl is Map
          ? (repl['name']?.toString() ?? shipId)
          : (prod is Map ? prod['name']?.toString() : null) ?? shipId;
      final originalName = orig is Map
          ? (orig['name']?.toString() ?? boqId)
          : (isReplaced ? boqId : shipName);
      final unit = (isReplaced && repl is Map)
          ? repl['unit']?.toString()
          : (prod is Map ? prod['unit']?.toString() : null);
      _appendSelectedProduct(
        productId: isReplaced ? (replacementId.isNotEmpty ? replacementId : shipId) : shipId,
        name: localizedApiProductName(context, shipName),
        quantity: qty,
        color: shipColor,
        originalColor: boqColor,
        productLineIndex: lineIndex,
        originalProductId: boqId,
        originalName: localizedApiProductName(context, originalName),
        replacementProductId: isReplaced ? (replacementId.isNotEmpty ? replacementId : shipId) : null,
        isReplaced: isReplaced,
        unit: unit,
      );
    }
  }

  Future<void> _resolveStoreForSelectedProject() async {
    if (widget.orderId != null && widget.orderId!.trim().isNotEmpty) {
      await _applyStoreFromOrderId(widget.orderId!.trim());
      return;
    }
    final pid = _selectedProjectId;
    if (pid == null) {
      if (mounted) setState(() => _resolvedStoreId = null);
      return;
    }
    final project = _projects.cast<Project?>().firstWhere(
          (p) => p?.id == pid,
          orElse: () => null,
        );
    final depot = project?.depotId?.trim();
    if (depot != null && depot.isNotEmpty) {
      setState(() => _resolvedStoreId = depot);
      await _refreshLocationStock();
      return;
    }
    try {
      final res = await _apiService.get('/orders', queryParams: {'project': pid});
      if (!mounted || res['success'] != true || res['data'] is! List) {
        setState(() => _resolvedStoreId = null);
        return;
      }
      for (final raw in res['data'] as List) {
        final o = Map<String, dynamic>.from(raw as Map);
        final st = o['status']?.toString() ?? '';
        if (st != 'approved' && st != 'completed') continue;
        final sid = o['approvedStoreId']?.toString() ?? o['approved_store_id']?.toString();
        if (sid != null && sid.trim().isNotEmpty) {
          setState(() => _resolvedStoreId = sid.trim());
          await _refreshLocationStock();
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _resolvedStoreId = null);
  }

  /// Remaining quantity still distributable from project budget (BOQ + supplementary).
  /// Source of truth is the real remaining envelope:
  ///   remaining = max(0, requested + supplementary - distributed)
  /// We avoid trusting stale `allowedQuantity` values which can drift after manual/admin flows.
  int _projectDistributableCap(ProjectProduct pp) {
    final req = pp.requestedQuantity;
    final baseReq = req > 0 ? req : pp.allowedQuantity;
    final dist = pp.distributedQuantity;
    final supp = pp.supplementaryQuantity > 0 ? pp.supplementaryQuantity : 0;
    final totalEnvelope = baseReq + supp;
    final remaining = totalEnvelope - dist;
    if (remaining <= 0) return 0;
    return remaining;
  }

  /// Distribution cap follows project "remaining + supplementary extra".
  /// This mirrors Project details where distributed = requested - allowed, and supplementary is extra.
  List<Map<String, dynamic>> get _projectProducts {
    if (_selectedProjectId == null) return [];
    final project = _projects.cast<Project?>().firstWhere(
          (p) => p?.id == _selectedProjectId,
          orElse: () => null,
        );
    if (project == null || project.products == null) return [];
    final out = <Map<String, dynamic>>[];
    final list = project.products!;
    final hasOrderCap = widget.orderId != null &&
        widget.orderId!.trim().isNotEmpty &&
        _orderApprovedQtyByKey.isNotEmpty;
    for (var i = 0; i < list.length; i++) {
      final pp = list[i];
      final projectCap = _projectDistributableCap(pp);
      // Skip only lines with no project budget at all (no BOQ / supp row).
      if (projectCap <= 0 &&
          pp.requestedQuantity <= 0 &&
          pp.supplementaryQuantity <= 0) {
        continue;
      }
      final boqKey = _lineKey(pp.product, pp.color);
      // When opened from an order, only show products that belong to that order (BOQ keys).
      if (hasOrderCap && (_orderApprovedQtyByKey[boqKey] ?? 0) <= 0) {
        continue;
      }
      final maxQ = _maxDistributableForLine(pp, i);
      // Fully covered by lines already in the form — no need to offer again.
      if (maxQ <= 0) continue;
      final ship = _orderShipByBoqKey[boqKey];
      final base = pp.productName ?? pp.product;
      final baseAr = localizedApiProductName(context, base);
      String name;
      if (ship != null) {
        final shipName = localizedApiProductName(context, ship['name']?.toString() ?? '');
        name = '$baseAr → $shipName';
      } else if (pp.color != null && pp.color!.isNotEmpty) {
        name = '$baseAr (${localizedVariantOrColorLabel(context, pp.color!)})';
      } else {
        name = baseAr;
      }
      out.add({
        'productId': _canonicalProductId(pp.product),
        'name': name,
        'color': pp.color,
        'maxQuantity': maxQ,
        'productLineIndex': i,
        if (ship != null) 'shipProductId': ship['productId'],
        if (ship != null) 'shipColor': ship['color'],
        if (ship != null) 'shipName': ship['name'],
        if (ship != null) 'isOrderReplaced': true,
      });
    }
    return out;
  }

  bool get _hasRequestedProductsForProject {
    if (_selectedProjectId == null) return false;
    final project = _projects.cast<Project?>().firstWhere(
          (p) => p?.id == _selectedProjectId,
          orElse: () => null,
        );
    if (project == null || project.products == null) return false;
    final hasOrderCap = widget.orderId != null &&
        widget.orderId!.trim().isNotEmpty &&
        _orderApprovedQtyByKey.isNotEmpty;
    return project.products!.any((pp) {
      if (_projectDistributableCap(pp) > 0) return true;
      if (hasOrderCap && (_orderApprovedQtyByKey[_lineKey(pp.product, pp.color)] ?? 0) > 0) {
        return true;
      }
      return false;
    });
  }

  String _normalizeVariant(String? c) => (c ?? '').trim().toLowerCase();
  String _lineKey(String productId, String? color) => '${_canonicalProductId(productId)}|${_normalizeVariant(color)}';

  /// Same id as in [ProjectProduct.product] (avoids mismatch Map vs String from JSON).
  String _canonicalProductId(dynamic id) {
    if (id == null) return '';
    if (id is Map) {
      final m = id['id'] ?? id['_id'];
      return m?.toString().trim() ?? '';
    }
    return id.toString().trim();
  }

  /// Quantities already chosen in this form for this BOQ row (index in [Project.products]).
  /// Counts replacements via [originalProductId] even when [productId] is the ship product.
  int _alreadySelectedForLine(int productLineIndex, ProjectProduct pp) {
    var sum = 0;
    final pid = _canonicalProductId(pp.product);
    final want = _normalizeVariant(pp.color);
    for (final p in _selectedProducts) {
      final idx = p['productLineIndex'];
      if (idx is int && idx == productLineIndex) {
        sum += _parseQuantity(p['quantity']);
        continue;
      }
      if (idx is int) continue; // belongs to another BOQ row
      final boqId = _canonicalProductId(p['originalProductId'] ?? p['productId']);
      final boqColor = p['originalColor'] ?? p['color'];
      if (boqId == pid && _normalizeVariant(boqColor as String?) == want) {
        sum += _parseQuantity(p['quantity']);
      }
    }
    return sum;
  }

  num _warehouseQtyForLine(String productId, String? color) {
    final want = _normalizeVariant(color);
    final targetPid = _canonicalProductId(productId);
    final assignedStore = _orderStoreByProductKey[_lineKey(productId, color)];
    num sum = 0;
    for (final s in _locationStock) {
      final pid = _canonicalProductId(s.documentProductId ?? s.product?.id);
      if (pid != targetPid) continue;
      final sid = s.documentStoreId ?? s.store?.id ?? '';
      if (assignedStore != null && assignedStore.isNotEmpty && sid != assignedStore) continue;
      final sv = _normalizeVariant(s.variant);
      if (want.isEmpty) {
        if (sv.isEmpty) sum += s.quantity;
      } else if (sv == want) {
        sum += s.quantity;
      }
    }
    // If project line expects a variant but stock rows are uncolored, treat uncolored stock
    // as fallback availability for that product to avoid false "no stock" blocking.
    if (want.isNotEmpty && sum == 0) {
      for (final s in _locationStock) {
        final pid = _canonicalProductId(s.documentProductId ?? s.product?.id);
        if (pid != targetPid) continue;
        final sv = _normalizeVariant(s.variant);
        if (sv.isEmpty) sum += s.quantity;
      }
    }
    // BOQ line without variant but stock rows only carry variant/color (common legacy case).
    if (want.isEmpty && sum == 0) {
      for (final s in _locationStock) {
        final pid = _canonicalProductId(s.documentProductId ?? s.product?.id);
        if (pid != targetPid) continue;
        sum += s.quantity;
      }
    }
    return sum;
  }

  bool get _canReplaceProducts {
    final role = Provider.of<AuthProvider>(context, listen: false).user?.role;
    return isAdminLike(role);
  }

  int _projectOrderCapForLine(ProjectProduct pp, int productLineIndex) {
    final projectCap = _projectDistributableCap(pp).toDouble();
    var cap = projectCap;
    final hasOrderCap = widget.orderId != null &&
        widget.orderId!.trim().isNotEmpty &&
        _orderApprovedQtyByKey.isNotEmpty;
    if (hasOrderCap) {
      final key = _lineKey(pp.product, pp.color);
      final orderCap = (_orderApprovedQtyByKey[key] ?? 0).toDouble();
      if (orderCap > 0) {
        // Order already reserved BOQ — project "remaining" can be 0 even though
        // this order still needs to be distributed (e.g. abb → adc for 200).
        cap = orderCap;
        if (projectCap > 0) {
          cap = min(cap, projectCap);
        }
      } else {
        cap = 0;
      }
    }
    final already = _alreadySelectedForLine(productLineIndex, pp);
    final m = cap - already;
    if (m <= 0) return 0;
    return m.floor();
  }

  int _maxDistributableForLine(ProjectProduct pp, int productLineIndex) {
    if (_resolvedStoreId == null) return 0;
    final projectOrderCap = _projectOrderCapForLine(pp, productLineIndex);
    // Admin/Manager may select beyond warehouse stock and replace the product.
    if (_canReplaceProducts) return projectOrderCap;
    // If manager already replaced this BOQ line on the order, use replacement stock.
    final ship = _orderShipByBoqKey[_lineKey(pp.product, pp.color)];
    final stockPid = ship != null
        ? _canonicalProductId(ship['productId'])
        : _canonicalProductId(pp.product);
    final stockColor = ship != null ? ship['color'] as String? : pp.color;
    final wh = _warehouseQtyForLine(stockPid, stockColor);
    final m = min(projectOrderCap.toDouble(), wh.toDouble());
    if (m <= 0) return 0;
    return m.floor();
  }

  Future<void> _refreshLocationStock() async {
    if (_resolvedStoreId == null && _orderStoreIds.isEmpty) {
      if (mounted) setState(() => _locationStock = []);
      return;
    }
    try {
      if (_orderStoreIds.length > 1) {
        final res = await _apiService.get('/stock');
        if (!mounted) return;
        if (res['success'] == true && res['data'] != null) {
          final list = res['data'] as List;
          setState(() {
            _locationStock = list
                .map((e) => Stock.fromJson(Map<String, dynamic>.from(e as Map)))
                .where((s) => _orderStoreIds.contains(s.documentStoreId ?? s.store?.id ?? ''))
                .toList();
          });
        } else {
          setState(() => _locationStock = []);
        }
        return;
      }
      final loc = _resolvedStoreId;
      if (loc == null) {
        if (mounted) setState(() => _locationStock = []);
        return;
      }
      final isDepot = _depots.any((d) => d.id == loc);
      final res = await _apiService.get(
        '/stock',
        queryParams: isDepot ? {'depot': loc} : {'store': loc},
      );
      if (!mounted) return;
      if (res['success'] == true && res['data'] != null) {
        final list = res['data'] as List;
        setState(() {
          _locationStock = list
              .map((e) => Stock.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        });
      } else {
        setState(() => _locationStock = []);
      }
    } catch (_) {
      if (mounted) setState(() => _locationStock = []);
    }
  }

  int _parseQuantity(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Run all 3 API calls in parallel.
      // Use full projects payload so supplementaryQuantity is available for distribution max.
      final results = await Future.wait([
        _apiService.get('/projects'),
        _apiService.get('/depots').catchError((_) => <String, dynamic>{}),
      ]);
      final projectsRes = results[0];
      final depotsRes = results[1];
      if (projectsRes['success'] == true && projectsRes['data'] != null) {
        _projects = (projectsRes['data'] as List)
            .map((e) => Project.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (depotsRes['success'] == true && depotsRes['data'] != null) {
        _depots = (depotsRes['data'] as List)
            .map((e) => Store.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      setState(() => _loading = false);
      if (widget.orderId != null && widget.orderId!.trim().isNotEmpty) {
        await _applyStoreFromOrderId(widget.orderId!.trim());
      } else if (_selectedProjectId != null) {
        await _resolveStoreForSelectedProject();
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _addProduct() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedProjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBarError(l10n.selectProjectFirst));
      return;
    }
    if (_resolvedStoreId == null) {
      ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBarError(l10n.distributionDepotUnresolved));
      return;
    }
    await _refreshLocationStock();
    if (!mounted) return;
    final available = _projectProducts;
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBarError(
          _hasRequestedProductsForProject ? l10n.noStockAtSelectedSource : l10n.noProductsRequested,
        ),
      );
      return;
    }
    int selectedIndex = 0;
    int maxQty = available.isNotEmpty ? _parseQuantity(available[0]['maxQuantity']) : 0;
    final qtyController = TextEditingController(text: '0');
    showDialog(
      context: context,
      builder: (ctx) {
        final dl10n = AppLocalizations.of(ctx)!;
        return StatefulBuilder(
        builder: (ctx, setDialogState) {
          maxQty = _parseQuantity(available[selectedIndex]['maxQuantity']);
          return AlertDialog(
            title: Text(dl10n.addProduct),
            content: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<int>(
                      value: selectedIndex,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: dl10n.product, border: const OutlineInputBorder()),
                      selectedItemBuilder: (ctx) => available.asMap().entries.map((e) {
                        final mq = '${_parseQuantity(e.value['maxQuantity'])}';
                        return Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          dl10n.productNameWithMaxQty(e.value['name']?.toString() ?? '', mq),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          softWrap: false,
                        ),
                      );
                      }).toList(),
                      items: available.asMap().entries.map((e) {
                        final mq = '${_parseQuantity(e.value['maxQuantity'])}';
                        return DropdownMenuItem(
                        value: e.key,
                        child: Text(
                          dl10n.productNameWithMaxQty(e.value['name']?.toString() ?? '', mq),
                          softWrap: true,
                          maxLines: null,
                          overflow: TextOverflow.clip,
                        ),
                      );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() {
                            selectedIndex = v;
                            qtyController.text = '0';
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: dl10n.quantity,
                        hintText: dl10n.maxQtyHintNumber('$maxQty'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(dl10n.cancel)),
              FilledButton(
                onPressed: () async {
                  final quantity = int.tryParse(qtyController.text) ?? 0;
                  if (quantity <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBarError(dl10n.pleaseEnterQuantity));
                    return;
                  }
                  if (quantity > maxQty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      AppTheme.snackBarError(dl10n.quantityExceedsMax('$maxQty')),
                    );
                    return;
                  }
                  if (selectedIndex < 0 || selectedIndex >= available.length) return;
                  final p = available[selectedIndex];
                  final productId = _canonicalProductId(p['productId']);
                  final color = p['color'] as String?;
                  final lineIndex = p['productLineIndex'] is int ? p['productLineIndex'] as int : null;
                  final orderShip = _orderShipByBoqKey[_lineKey(productId, color)];
                  // Order already has a replacement for this BOQ line — ship the replacement.
                  if (orderShip != null) {
                    final shipPid = _canonicalProductId(orderShip['productId']);
                    final shipColor = orderShip['color'] as String?;
                    final warehouseQty = _warehouseQtyForLine(shipPid, shipColor).floor();
                    if (warehouseQty < quantity) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        AppTheme.snackBarError(dl10n.outOfStock),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    _appendSelectedProduct(
                      productId: shipPid,
                      name: localizedApiProductName(context, orderShip['name']?.toString() ?? shipPid),
                      quantity: quantity,
                      color: shipColor,
                      originalColor: color,
                      productLineIndex: lineIndex,
                      originalProductId: productId,
                      originalName: p['name']?.toString()?.split(' → ').first ?? productId,
                      replacementProductId: shipPid,
                      isReplaced: true,
                      unit: orderShip['unit']?.toString(),
                    );
                    return;
                  }
                  final warehouseQty = _warehouseQtyForLine(productId, color).floor();
                  if (warehouseQty < quantity) {
                    if (!_canReplaceProducts) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        AppTheme.snackBarError(dl10n.outOfStock),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    final replaced = await _promptAndReplaceProduct(
                      originalProductId: productId,
                      originalName: p['name']?.toString() ?? '',
                      color: color,
                      quantity: quantity,
                      productLineIndex: lineIndex,
                    );
                    if (replaced && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!.productReplacedSuccessfully),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                    return;
                  }
                  Navigator.pop(ctx);
                  _appendSelectedProduct(
                    productId: productId,
                    name: p['name']?.toString() ?? '',
                    quantity: quantity,
                    color: color,
                    productLineIndex: lineIndex,
                  );
                },
                child: Text(dl10n.add),
              ),
            ],
          );
        },
      );
      },
    );
  }

  void _appendSelectedProduct({
    required String productId,
    required String name,
    required int quantity,
    String? color,
    String? originalColor,
    int? productLineIndex,
    String? originalProductId,
    String? originalName,
    String? replacementProductId,
    bool isReplaced = false,
    String? unit,
  }) {
    setState(() {
      if (productLineIndex != null && !isReplaced) {
        final existingIdx = _selectedProducts.indexWhere((sp) => sp['productLineIndex'] == productLineIndex);
        if (existingIdx >= 0) {
          final prev = _parseQuantity(_selectedProducts[existingIdx]['quantity']);
          _selectedProducts[existingIdx]['quantity'] = prev + quantity;
          return;
        }
      }
      _selectedProducts.add({
        'productId': productId,
        'name': name,
        'quantity': quantity,
        'color': color,
        if (originalColor != null) 'originalColor': originalColor,
        if (productLineIndex != null) 'productLineIndex': productLineIndex,
        'originalProductId': originalProductId ?? productId,
        'originalName': originalName ?? name,
        if (replacementProductId != null) 'replacementProductId': replacementProductId,
        'isReplaced': isReplaced,
        if (unit != null) 'unit': unit,
      });
    });
  }

  Future<bool> _promptAndReplaceProduct({
    required String originalProductId,
    required String originalName,
    String? color,
    required int quantity,
    int? productLineIndex,
  }) async {
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
            FilledButton(
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
              child: Text(dl10n.replaceProduct),
            ),
          ],
        );
      },
    );
    if (wantReplace != true || !mounted) return false;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return false;
    final replacements = await _showReplacementPicker(
      excludeProductId: originalProductId,
      requiredQuantity: quantity,
    );
    if (replacements == null || replacements.isEmpty || !mounted) return false;
    for (final replacement in replacements) {
      final qty = replacement['quantity'] as int? ?? 0;
      if (qty <= 0) continue;
      _appendSelectedProduct(
        productId: replacement['productId'] as String,
        name: replacement['name'] as String,
        quantity: qty,
        color: replacement['color'] as String?,
        originalColor: color,
        productLineIndex: productLineIndex,
        originalProductId: originalProductId,
        originalName: originalName,
        replacementProductId: replacement['productId'] as String,
        isReplaced: true,
        unit: replacement['unit'] as String?,
      );
    }
    return true;
  }

  Future<List<Map<String, dynamic>>?> _showReplacementPicker({
    required String excludeProductId,
    required int requiredQuantity,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    await _refreshLocationStock();
    if (!mounted) return null;

    final candidates = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final s in _locationStock) {
      final pid = _canonicalProductId(s.documentProductId ?? s.product?.id);
      if (pid.isEmpty || pid == excludeProductId) continue;
      final variant = s.variant?.trim();
      final key = _lineKey(pid, variant);
      if (seen.contains(key)) continue;
      final available = _warehouseQtyForLine(pid, variant).floor();
      if (available <= 0) continue;
      seen.add(key);
      final rawName = s.product?.name ?? pid;
      final name = localizedApiProductName(context, rawName);
      String variantLabel = '';
      if (variant != null && variant.isNotEmpty) {
        variantLabel = localizedVariantOrColorLabel(context, variant);
      } else {
        final colors = s.product?.availableColors ?? const <String>[];
        if (colors.isNotEmpty) {
          variantLabel = colors.map((c) => localizedVariantOrColorLabel(context, c)).join(', ');
        }
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
      ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBarError(l10n.noProductsWithStock));
      return null;
    }

    final searchController = TextEditingController();
    final qtyControllers = <String, TextEditingController>{};
    for (final c in candidates) {
      final key = _lineKey(c['productId'] as String, c['color'] as String?);
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
                                  final key = _lineKey(c['productId'] as String, c['color'] as String?);
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
                        final key = _lineKey(c['productId'] as String, c['color'] as String?);
                        if (!selected.contains(key)) continue;
                        final qty = int.tryParse(qtyControllers[key]?.text.trim() ?? '') ?? 0;
                        final available = c['available'] as int;
                        if (qty <= 0) continue;
                        if (qty > available) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            AppTheme.snackBarError(dl10n.quantityExceedsMax('$available')),
                          );
                          return;
                        }
                        sum += qty;
                        result.add({...c, 'quantity': qty});
                      }
                      if (result.isEmpty || sum != requiredQuantity) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          AppTheme.snackBarError(dl10n.replacementQtyMustMatch('$requiredQuantity')),
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

  void _removeProduct(int index) {
    setState(() => _selectedProducts.removeAt(index));
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedProjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBarError(l10n.selectProjectFirst));
      return;
    }
    if (_resolvedStoreId == null) {
      ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBarError(l10n.distributionDepotUnresolved));
      return;
    }
    if (_selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBarError(l10n.addAtLeastOneProduct));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final products = _selectedProducts.map((p) {
        final isReplaced = p['isReplaced'] == true;
        final originalId = (p['originalProductId'] ?? p['productId']).toString();
        final shipId = p['productId'].toString();
        final map = <String, dynamic>{
          'product': {'id': shipId},
          'quantity': p['quantity'] as int,
          'original_product_id': originalId,
          'is_replaced': isReplaced,
        };
        if (isReplaced) {
          map['replacement_product_id'] = p['replacementProductId'] ?? shipId;
          final originalColor = p['originalColor'] as String?;
          if (originalColor != null && originalColor.toString().trim().isNotEmpty) {
            map['original_color'] = originalColor.toString().trim().toLowerCase();
          }
        }
        final color = p['color'] as String?;
        if (color != null && color.toString().trim().isNotEmpty) {
          map['color'] = color.toString().trim().toLowerCase();
        }
        return map;
      }).toList();
      final payload = <String, dynamic>{
        'bonAlimentation': _serialNumberController.text.trim().isEmpty ? null : _serialNumberController.text.trim(),
        'project': _selectedProjectId,
        'distributionDate': _distributionDate.toIso8601String().split('T')[0],
        'products': products,
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        if (widget.orderId != null && widget.orderId!.trim().isNotEmpty) 'orderId': widget.orderId!.trim(),
      };
      if (_depots.any((d) => d.id == _resolvedStoreId)) {
        payload['depot'] = _resolvedStoreId;
      } else {
        payload['store'] = _resolvedStoreId;
      }
      final res = await _apiService.post('/distributions', payload);
      if (mounted) {
        final materialRequest = res['data']?['bonAlimentation'] ?? res['data']?['bon_alimentation'] ?? 'N/A';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.distributionCreated(materialRequest)),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _saving = false;
          _selectedProducts.clear();
          _notesController.clear();
        });
        Navigator.of(context).pop(true);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WarehouseApprovedOrdersScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.createDistribution)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _projects.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.createDistribution)),
        body: ConnectionErrorWidget(message: _error!, onRetry: _loadData),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createDistribution),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _serialNumberController,
              decoration: InputDecoration(
                labelText: l10n.materialRequestOptional,
                hintText: l10n.materialRequestHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _distributionDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _distributionDate = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: '${l10n.distributionDate} *',
                  border: const OutlineInputBorder(),
                ),
                child: Text(
                  L10nFormatters.formatDateShort(context, _distributionDate),
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedProjectId,
              isExpanded: true,
              decoration: InputDecoration(labelText: '${l10n.project} *', border: const OutlineInputBorder()),
              items: _projects.map((p) => DropdownMenuItem(
                value: p.id,
                child: Text(p.displayName(context), softWrap: true, maxLines: null, overflow: TextOverflow.clip),
              )).toList(),
              onChanged: (widget.orderId != null && widget.orderId!.trim().isNotEmpty)
                  ? null
                  : (v) async {
                      setState(() {
                        _selectedProjectId = v;
                        _selectedProducts.clear();
                        _resolvedStoreId = null;
                      });
                      await _resolveStoreForSelectedProject();
                      if (mounted) setState(() {});
                    },
            ),
            if (_selectedProjectId != null && _resolvedStoreId == null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.distributionDepotUnresolved,
                style: TextStyle(color: Colors.orange[800], fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.productsRequiredLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                TextButton.icon(
                  onPressed: (_hasRequestedProductsForProject && _resolvedStoreId != null)
                      ? _addProduct
                      : null,
                  icon: const Icon(Icons.add),
                  label: Text(_selectedProjectId == null
                      ? l10n.selectProjectFirstShort
                      : _resolvedStoreId == null
                          ? l10n.setProjectDepotShort
                          : !_hasRequestedProductsForProject
                              ? l10n.noProductsRequestedShort
                              : l10n.add),
                ),
              ],
            ),
            if (_selectedProducts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.noProductsAdded, style: const TextStyle(color: Colors.grey)),
              )
            else
              ..._selectedProducts.asMap().entries.map((e) {
                final item = e.value;
                final isReplaced = item['isReplaced'] == true;
                final originalName = item['originalName']?.toString();
                return ListTile(
                  title: Text(
                    item['name'] ?? '',
                    softWrap: true,
                    maxLines: null,
                    overflow: TextOverflow.clip,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.qtyWithOptionalColor(
                          '${item['quantity']}',
                          (item['color'] as String?) != null ? ' • ${item['color']}' : '',
                        ),
                        softWrap: true,
                        maxLines: null,
                        overflow: TextOverflow.clip,
                      ),
                      if (isReplaced) ...[
                        const SizedBox(height: 4),
                        Text(
                          '🟢 ${l10n.productReplacedSuccessfully}',
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        if (originalName != null && originalName.isNotEmpty)
                          Text(
                            '${l10n.originalProduct}: $originalName',
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                          ),
                        Text(
                          '${l10n.replacedByProduct}: ${item['name']}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                      ],
                    ],
                  ),
                  isThreeLine: isReplaced,
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () => _removeProduct(e.key),
                  ),
                );
              }),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: l10n.notesOptional,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Material(
                  color: AppTheme.error,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_error!, style: const TextStyle(color: Colors.white))),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.createDistribution),
            ),
          ],
        ),
      ),
    );
  }
}
