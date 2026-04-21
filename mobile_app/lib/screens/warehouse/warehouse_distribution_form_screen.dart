import 'dart:math' show min;

import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/product_localized.dart';
import '../../../utils/project_localized.dart';
import '../../../utils/l10n_formatters.dart';
import '../../../models/stock.dart';
import '../../../models/store.dart';
import '../../../models/user.dart';
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
  /// Order-level approved quantities (per product+variant) when opened from an order.
  final Map<String, int> _orderApprovedQtyByKey = {};
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
      final proj = data['project'];
      String? projectId = _selectedProjectId;
      if (proj is Map) {
        final pid = proj['id']?.toString();
        if (pid != null && pid.isNotEmpty) projectId = pid;
      }
      final orderApproved = <String, int>{};
      final prods = data['products'];
      if (prods is List) {
        for (final raw in prods) {
          if (raw is! Map) continue;
          final p = Map<String, dynamic>.from(raw);
          final pid = _canonicalProductId(p['product']);
          if (pid.isEmpty) continue;
          final color = p['color']?.toString() ?? p['variant']?.toString();
          final key = _lineKey(pid, color);
          final qty = _parseQuantity(p['quantity']);
          if (qty <= 0) continue;
          orderApproved[key] = (orderApproved[key] ?? 0) + qty;
        }
      }
      setState(() {
        if (sid != null && sid.trim().isNotEmpty) _resolvedStoreId = sid.trim();
        if (projectId != null && projectId.trim().isNotEmpty) _selectedProjectId = projectId.trim();
        _orderApprovedQtyByKey
          ..clear()
          ..addAll(orderApproved);
      });
      await _refreshLocationStock();
    } catch (_) {}
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
    for (var i = 0; i < list.length; i++) {
      final pp = list[i];
      final projectCap = _projectDistributableCap(pp);
      // Skip only lines with no project budget at all (no BOQ / supp row).
      if (projectCap <= 0 &&
          pp.requestedQuantity <= 0 &&
          pp.supplementaryQuantity <= 0) {
        continue;
      }
      final maxQ = _maxDistributableForLine(pp, i);
      // Keep lines with maxQ == 0 so the user can see the product and why it is blocked
      // (no stock at source or BOQ line already filled in this form).
      final base = pp.productName ?? pp.product;
      final baseAr = localizedApiProductName(context, base);
      final name = pp.color != null && pp.color!.isNotEmpty
          ? '$baseAr (${localizedVariantOrColorLabel(context, pp.color!)})'
          : baseAr;
      out.add({
        'productId': _canonicalProductId(pp.product),
        'name': name,
        'color': pp.color,
        'maxQuantity': maxQ,
        'productLineIndex': i,
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
    return project.products!.any((pp) => _projectDistributableCap(pp) > 0);
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
  /// Falls back to product+color for rows added before [productLineIndex] was stored (e.g. hot reload).
  int _alreadySelectedForLine(int productLineIndex, ProjectProduct pp) {
    var sum = 0;
    final pid = _canonicalProductId(pp.product);
    final want = _normalizeVariant(pp.color);
    for (final p in _selectedProducts) {
      final idx = p['productLineIndex'];
      if (idx is int && idx == productLineIndex) {
        sum += _parseQuantity(p['quantity']);
      } else if (idx == null) {
        if (_canonicalProductId(p['productId']) == pid && _normalizeVariant(p['color'] as String?) == want) {
          sum += _parseQuantity(p['quantity']);
        }
      }
    }
    return sum;
  }

  num _warehouseQtyForLine(String productId, String? color) {
    final want = _normalizeVariant(color);
    final targetPid = _canonicalProductId(productId);
    num sum = 0;
    for (final s in _locationStock) {
      final pid = _canonicalProductId(s.documentProductId ?? s.product?.id);
      if (pid != targetPid) continue;
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

  int _maxDistributableForLine(ProjectProduct pp, int productLineIndex) {
    if (_resolvedStoreId == null) return 0;
    final wh = _warehouseQtyForLine(pp.product, pp.color);
    final projectCap = _projectDistributableCap(pp);
    var cap = min<num>(projectCap, wh);
    final hasOrderCap = widget.orderId != null &&
        widget.orderId!.trim().isNotEmpty &&
        _orderApprovedQtyByKey.isNotEmpty;
    if (hasOrderCap) {
      final key = _lineKey(pp.product, pp.color);
      final orderCap = _orderApprovedQtyByKey[key] ?? 0;
      cap = min<num>(cap, orderCap);
    }
    final already = _alreadySelectedForLine(productLineIndex, pp);
    final m = cap - already;
    if (m <= 0) return 0;
    return m.floor();
  }

  Future<void> _refreshLocationStock() async {
    if (_resolvedStoreId == null) {
      if (mounted) setState(() => _locationStock = []);
      return;
    }
    final isDepot = _depots.any((d) => d.id == _resolvedStoreId);
    try {
      final res = await _apiService.get(
        '/stock',
        queryParams: isDepot ? {'depot': _resolvedStoreId!} : {'store': _resolvedStoreId!},
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
                onPressed: () {
                  final quantity = int.tryParse(qtyController.text) ?? 0;
                  if (maxQty <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      AppTheme.snackBarError(dl10n.noStockAtSelectedSource),
                    );
                    return;
                  }
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
                  if (selectedIndex >= 0 && selectedIndex < available.length) {
                    final p = available[selectedIndex];
                    Navigator.pop(ctx);
                    setState(() {
                      final lineIndex = p['productLineIndex'] is int ? p['productLineIndex'] as int : null;
                      if (lineIndex != null) {
                        final existingIdx = _selectedProducts.indexWhere((sp) => sp['productLineIndex'] == lineIndex);
                        if (existingIdx >= 0) {
                          final prev = _parseQuantity(_selectedProducts[existingIdx]['quantity']);
                          _selectedProducts[existingIdx]['quantity'] = prev + quantity;
                          return;
                        }
                      }
                      _selectedProducts.add({
                        'productId': p['productId'],
                        'name': p['name'],
                        'quantity': quantity,
                        'color': p['color'],
                        if (lineIndex != null) 'productLineIndex': lineIndex,
                      });
                    });
                  }
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
        final map = <String, dynamic>{
          'product': {'id': p['productId']},
          'quantity': p['quantity'] as int,
        };
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
              ..._selectedProducts.asMap().entries.map((e) => ListTile(
                title: Text(
                  e.value['name'] ?? '',
                  softWrap: true,
                  maxLines: null,
                  overflow: TextOverflow.clip,
                ),
                subtitle: Text(
                  l10n.qtyWithOptionalColor(
                    '${e.value['quantity']}',
                    (e.value['color'] as String?) != null ? ' • ${e.value['color']}' : '',
                  ),
                  softWrap: true,
                  maxLines: null,
                  overflow: TextOverflow.clip,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  onPressed: () => _removeProduct(e.key),
                ),
              )),
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
