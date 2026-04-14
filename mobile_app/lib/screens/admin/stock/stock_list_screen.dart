import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/product.dart';
import '../../../models/stock.dart';
import '../../../models/store.dart';
import '../../../services/api_service.dart';
import '../../../utils/decimal_input.dart';
import '../../../utils/product_localized.dart';
import '../../../utils/store_localized.dart';
import '../../../widgets/app_search_bar.dart';
import '../../../widgets/connection_error_widget.dart';
import '../../../widgets/count_badge.dart';

/// Filtre produits pour le sélecteur Add/Edit stock (nom + fabricant).
List<Product> _filterStockDialogProducts(List<Product> sorted, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return sorted;
  return sorted.where((p) {
    if (productNameMatchesSearchQuery(p.name, p.id, q)) return true;
    if (p.nameAr != null && p.nameAr!.toLowerCase().contains(q)) return true;
    final manu = p.manufacturer?.trim().toLowerCase() ?? '';
    return manu.isNotEmpty && manu.contains(q);
  }).toList();
}

class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key});

  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<Stock> _stocks = [];
  List<Product> _products = [];
  List<Store> _stores = [];
  /// Sum of unread warehouse `quantityChange` per product+store (from `/stock/notifications`).
  Map<String, int> _warehouseAddedByProductStore = {};
  bool _loading = true;
  String? _error;
  bool _showSearch = false;

  /// Matches backend stock line: product + store + optional color (variance).
  static String _productStoreColorKey(String productId, String storeId, String? color) {
    final c = (color == null || color.isEmpty) ? '' : color.trim().toLowerCase();
    return '$productId|$storeId|$c';
  }

  static String _normId(String? v) {
    if (v == null) return '';
    return v.toString().trim();
  }

  /// Nombre de **produits distincts** dans les lignes affichées (recherche incluse).
  static int _distinctProductCount(List<Stock> stocks) {
    final ids = <String>{};
    for (final s in stocks) {
      final id = _normId(s.documentProductId ?? s.product?.id);
      if (id.isNotEmpty) {
        ids.add(id);
      }
    }
    return ids.length;
  }

  int _warehouseAddedQtyFor(Stock stock) {
    final pid = _normId(stock.product?.id);
    final sid = _normId(stock.store?.id);
    if (pid.isEmpty || sid.isEmpty) return 0;
    final c = _normId(stock.variant);
    final k = _productStoreColorKey(pid, sid, c.isEmpty ? null : c);
    return _warehouseAddedByProductStore[k] ?? 0;
  }

  /// Line embedded in `/stock` first; then full `/products` cache so Manufacture shows above Store when set.
  String? _resolvedManufacturer(Stock stock) {
    final sp = stock.product;
    if (sp == null) return null;
    final m = sp.manufacturer?.trim();
    if (m != null && m.isNotEmpty) return m;
    for (final p in _products) {
      if (p.id != sp.id) continue;
      final pm = p.manufacturer?.trim();
      if (pm != null && pm.isNotEmpty) return pm;
      break;
    }
    return null;
  }

  Future<void> _markStockNotificationsRead() async {
    try {
      await _apiService.put('/stock/notifications-read', {});
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadStocks();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Product row for **Add Stock** dropdown only: stays within [itemHeight] (no red overflow).
  Widget _productDropdownRowCompact(BuildContext context, Product p) {
    final l10n = AppLocalizations.of(context)!;
    final m = p.manufacturer?.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            p.displayName(context),
            softWrap: true,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.15),
          ),
          if (m != null && m.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(
              '${l10n.manufacturer}: $m',
              style: TextStyle(fontSize: 10, color: Colors.grey[700], height: 1.05),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  /// Bottom sheet : recherche + liste de produits (Add/Edit stock).
  Future<String?> _pickStockProductForDialog(
    BuildContext ctx,
    List<Product> sortedProducts,
    String? currentProductId,
  ) {
    return showModalBottomSheet<String>(
      context: ctx,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom),
        child: _StockProductPickerSheet(
          sortedProducts: sortedProducts,
          currentProductId: currentProductId,
          rowBuilder: (c, p) => _productDropdownRowCompact(c, p),
        ),
      ),
    );
  }

  List<Stock> get _filteredStocks {
    final q = _searchController.text.trim().toLowerCase();
    final list = q.isEmpty
        ? List<Stock>.from(_stocks)
        : _stocks.where((s) {
              final p = s.product;
              final nameMatch = p != null &&
                  (productNameMatchesSearchQuery(p.name, null, q) ||
                      (p.nameAr?.toLowerCase().contains(q) ?? false));
              final manu = _resolvedManufacturer(s)?.toLowerCase() ?? '';
              final rawVar = _variantResolution(s).raw;
              return nameMatch ||
                  (manu.isNotEmpty && manu.contains(q)) ||
                  (s.store?.name.toLowerCase().contains(q) ?? false) ||
                  (s.store?.nameAr?.toLowerCase().contains(q) ?? false) ||
                  (s.variant?.toLowerCase().contains(q) ?? false) ||
                  (rawVar?.toLowerCase().contains(q) ?? false);
            }).toList();
    list.sort((a, b) => (a.product?.name ?? '').toLowerCase().compareTo((b.product?.name ?? '').toLowerCase()));
    return list;
  }

  Future<void> _loadStocks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Map<String, int> addedMap = {};
      try {
        final nRes = await _apiService.get('/stock/notifications');
        if (nRes['success'] == true && nRes['data'] != null) {
          for (final e in (nRes['data'] as List)) {
            final m = Map<String, dynamic>.from(e as Map);
            final rd = m['read'];
            if (rd == true || rd == 'true') continue;
            final pid = _normId((m['productId'] ?? m['product_id'])?.toString());
            final sid = _normId((m['storeId'] ?? m['store_id'])?.toString());
            if (pid.isEmpty || sid.isEmpty) continue;
            final colRaw = _normId((m['variant'] ?? m['color'])?.toString());
            final raw = m['quantityChange'] ?? m['quantity_change'] ?? 0;
            final dv = raw is int ? raw : int.tryParse(raw.toString()) ?? 0;
            if (dv == 0) continue;
            final k = _productStoreColorKey(pid, sid, colRaw.isEmpty ? null : colRaw);
            addedMap[k] = (addedMap[k] ?? 0) + dv;
          }
        }
      } catch (_) {}
      final results = await Future.wait([
        _apiService.get('/stock'),
        _apiService.get('/products'),
        _apiService.get('/stores'),
      ]);
      final res = results[0];
      final productsRes = results[1];
      final storesRes = results[2];
      var products = List<Product>.from(_products);
      var stores = List<Store>.from(_stores);
      if (productsRes['success'] == true && productsRes['data'] != null) {
        products = (productsRes['data'] as List)
            .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (storesRes['success'] == true && storesRes['data'] != null) {
        stores = (storesRes['data'] as List)
            .map((e) => Store.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _stocks = (res['data'] as List)
              .map((e) => Stock.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _products = products;
          _stores = stores;
          _warehouseAddedByProductStore = addedMap;
          _loading = false;
        });
      } else {
        setState(() {
          _products = products;
          _stores = stores;
          _warehouseAddedByProductStore = addedMap;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _showAddStock() async {
    try {
    if (_products.isEmpty || _stores.isEmpty) {
      try {
        final [productsRes, storesRes] = await Future.wait([
          _apiService.get('/products'),
          _apiService.get('/stores'),
        ]);
        if (productsRes['success'] == true && productsRes['data'] != null) {
          _products = (productsRes['data'] as List)
              .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
        if (storesRes['success'] == true && storesRes['data'] != null) {
          _stores = (storesRes['data'] as List)
              .map((e) => Store.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
        if (mounted) {
          setState(() {});
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
        return;
      }
    }
    if (_products.isEmpty || _stores.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.addProductsAndStoresFirst)),
        );
      }
      return;
    }
    String? productId = _products.first.id;
    String? storeId = _stores.first.id;
    String? selectedColor;
    final qtyController = TextEditingController(text: '0');
    try {
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final l10n = AppLocalizations.of(ctx)!;
          final theme = Theme.of(ctx);
          // Closed dropdown must not use LayoutBuilder/FittedBox here: inside AlertDialog it can
          // resolve to zero intrinsic size so only the barrier is visible (M3 / some devices).
          final sortedProducts = List<Product>.from(_products)
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          Product? selectedProduct;
          try {
            selectedProduct = _products.firstWhere((p) => p.id == productId);
          } catch (_) {
            selectedProduct = null;
          }
          final sp = selectedProduct;
          final hasVariants = sp != null && sp.availableColors.isNotEmpty;
          final isGeogrid = sp?.category.any((c) => c.toLowerCase().contains('geogrid')) ?? false;
          if (hasVariants) {
            final p = sp;
            if (selectedColor == null || !p.availableColors.contains(selectedColor)) {
              selectedColor = p.availableColors.first;
            }
          } else {
            selectedColor = null;
          }
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            constraints: const BoxConstraints(maxWidth: 420),
            title: Text(l10n.addStock),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  KeyedSubtree(
                    key: ValueKey<String>('add-stock-product-field-$productId'),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.product,
                        border: const OutlineInputBorder(),
                        suffixIcon: Icon(Icons.arrow_drop_down, size: 24, color: theme.iconTheme.color),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      child: InkWell(
                        onTap: () async {
                          final id = await _pickStockProductForDialog(ctx, sortedProducts, productId);
                          if (id != null) {
                            setDialogState(() {
                              productId = id;
                              selectedColor = null;
                            });
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: sp != null
                                ? Text(
                                    sp.displayName(ctx),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.2),
                                  )
                                : Text('—', style: TextStyle(color: Colors.grey[600])),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>('add-stock-store-$storeId'),
                    initialValue: storeId,
                    decoration: InputDecoration(labelText: l10n.store, border: const OutlineInputBorder()),
                    items: _stores.map((s) => DropdownMenuItem(value: s.id, child: Text(s.displayName(context)))).toList(),
                    onChanged: (v) => setDialogState(() => storeId = v),
                  ),
                  if (hasVariants) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>('add-stock-variant-$productId-$selectedColor'),
                      initialValue: selectedColor,
                      decoration: InputDecoration(
                        labelText: isGeogrid ? l10n.variant : l10n.color,
                        border: const OutlineInputBorder(),
                      ),
                      items: sp.availableColors
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(sp.displayOneColor(ctx, c)),
                              ))
                          .toList(),
                      onChanged: (v) => setDialogState(() => selectedColor = v),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                    decoration: InputDecoration(labelText: l10n.quantity, border: const OutlineInputBorder()),
                  ),
                  if (hasVariants && selectedColor != null && selectedColor!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_outline, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${l10n.editStockSelectedVariant}: ${sp.displayOneColor(ctx, selectedColor!)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
              FilledButton(
                onPressed: () {
                  if (productId != null && storeId != null) {
                    final q = parseDecimalInput(qtyController.text);
                    if (q != null && q >= 0) Navigator.pop(ctx, true);
                  }
                },
                child: Text(l10n.add),
              ),
            ],
          );
        },
      ),
    );
    if (added != true || !mounted) return;
    final qty = parseDecimalInput(qtyController.text) ?? 0;
    productId ??= _products.first.id;
    storeId ??= _stores.first.id;
    try {
      await _apiService.post('/stock', {
        'productId': productId,
        'storeId': storeId,
        'quantity': qty,
        if (selectedColor != null && selectedColor!.isNotEmpty) 'variant': selectedColor,
      });
      if (mounted) _loadStocks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
    } finally {
      qtyController.dispose();
    }
    } catch (e, st) {
      assert(() {
        debugPrint('_showAddStock: $e\n$st');
        return true;
      }());
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

  void _showStockDetails(Stock stock) {
    final l10n = AppLocalizations.of(context)!;
    final manu = _resolvedManufacturer(stock);
    final resolvedVariant = _resolvedVariantForLine(stock);
    final sp = _productModelForStockLine(stock);
    final hasResolvedVariant = resolvedVariant != null && resolvedVariant.trim().isNotEmpty;
    /// Only this line’s chosen variant — never the full catalog list.
    final showVariantRow = hasResolvedVariant;

    String variantDetailCaption(BuildContext ctx) {
      final r = resolvedVariant!.trim();
      if (sp != null) return sp.displayOneColor(ctx, r);
      if (stock.product != null) return stock.product!.toDisplayProduct().displayOneColor(ctx, r);
      return r;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                l10n.stockDetails,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
              ),
              const SizedBox(height: 20),
              _detailRow(l10n.product, stock.product?.displayName(context) ?? '—'),
              if (manu != null) _detailRow(l10n.manufacturer, manu),
              _detailRow(l10n.store, stock.store != null ? stock.store!.displayName(context) : '—'),
              if (showVariantRow) _detailRow(l10n.variantOrColor, variantDetailCaption(context)),
              _detailRow(l10n.quantity, formatQuantityDisplay(stock.quantity)),
              if (stock.product?.unit != null)
                _detailRow(l10n.unit, stock.product!.displayUnit(context)),
              if (stock.product != null && stock.product!.categories.isNotEmpty)
                _detailRow(l10n.category, stock.product!.displayCategories(context)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _updateQuantity(stock);
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: Text(l10n.edit),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _deleteStock(stock);
                      },
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      icon: const Icon(Icons.delete, size: 18),
                      label: Text(l10n.delete),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _deleteStock(Stock stock) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteStock),
        content: Text(AppLocalizations.of(context)!.deleteStockRecordQuestion(
          stock.product?.displayName(context) ?? '—',
          stock.store != null ? stock.store!.displayName(context) : '',
          formatQuantityDisplay(stock.quantity),
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context)!.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: Text(AppLocalizations.of(context)!.delete)),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _apiService.delete('/stock/${stock.id}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.stockRecordDeleted), backgroundColor: Colors.green),
        );
        _loadStocks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Full [Product] for dialogs: prefer cache from `/products`, else minimal from stock line.
  Product? _productModelForStockLine(Stock stock) {
    final pid = stock.product?.id;
    if (pid == null || pid.isEmpty) return null;
    try {
      return _products.firstWhere((p) => p.id == pid);
    } catch (_) {
      return stock.product?.toDisplayProduct();
    }
  }

  /// Single place: full [Product] from cache (if any) + raw variant string (API + id + colors).
  ({Product? sp, String? raw}) _variantResolution(Stock stock) {
    final sp = _productModelForStockLine(stock);
    if (sp != null) {
      return (sp: sp, raw: stock.variantLabelForProductColors(sp.availableColors));
    }
    final v = stock.variant?.trim();
    if (v != null && v.isNotEmpty) return (sp: null, raw: v);
    // No cached Product row: still recover variant from doc id + product_id/store_id on the stock payload.
    return (sp: null, raw: stock.variantLabelForProductColors(stock.product?.availableColors ?? <String>[]));
  }

  /// Chosen variant for this line (API field + id/cache), same logic as Stock Details / Edit.
  String? _resolvedVariantForLine(Stock stock) => _variantResolution(stock).raw;

  /// Localized label for list row (never hides variant in a long title).
  String? _variantLabelForList(BuildContext context, Stock stock) {
    final res = _variantResolution(stock);
    final raw = res.raw;
    if (raw == null || raw.trim().isEmpty) return null;
    final r = raw.trim();
    if (res.sp != null) return res.sp!.displayOneColor(context, r);
    if (stock.product != null) return stock.product!.toDisplayProduct().displayOneColor(context, r);
    return r;
  }

  Future<void> _updateQuantity(Stock stock) async {
    if (_products.isEmpty || _stores.isEmpty) {
      try {
        final [productsRes, storesRes] = await Future.wait([
          _apiService.get('/products'),
          _apiService.get('/stores'),
        ]);
        if (mounted) {
          setState(() {
            if (productsRes['success'] == true && productsRes['data'] != null) {
              _products = (productsRes['data'] as List)
                  .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
                  .toList();
            }
            if (storesRes['success'] == true && storesRes['data'] != null) {
              _stores = (storesRes['data'] as List)
                  .map((e) => Store.fromJson(Map<String, dynamic>.from(e)))
                  .toList();
            }
          });
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
        return;
      }
    }

    final initialPid = stock.documentProductId ?? stock.product?.id;
    final initialSid = stock.documentStoreId ?? stock.store?.id;
    if (initialPid == null || initialPid.isEmpty || initialSid == null || initialSid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.couldNotLoadProduct)),
        );
      }
      return;
    }

    Product? spLine = _productModelForStockLine(stock);
    if (spLine == null) {
      try {
        spLine = _products.firstWhere((p) => p.id == initialPid);
      } catch (_) {
        spLine = null;
      }
    }
    if (spLine == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.couldNotLoadProduct)),
        );
      }
      return;
    }

    String? productId = initialPid;
    String? storeId = initialSid;
    String? selectedColor;
    final resolvedLine = _resolvedVariantForLine(stock);
    if (spLine.availableColors.isNotEmpty) {
      final raw = resolvedLine?.trim();
      if (raw != null && raw.isNotEmpty) {
        final matches = spLine.availableColors.where((c) => c.toLowerCase() == raw.toLowerCase()).toList();
        selectedColor = matches.isNotEmpty ? matches.first : spLine.availableColors.first;
      } else {
        selectedColor = spLine.availableColors.first;
      }
    }

    final qtyController = TextEditingController(text: stock.quantity.toString());
    bool? saved;
    num? qtyParsed;
    try {
      saved = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) {
            final l10n = AppLocalizations.of(ctx)!;
            final theme = Theme.of(ctx);
            final sortedProducts = List<Product>.from(_products)
              ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            Product? selectedProduct;
            try {
              selectedProduct = _products.firstWhere((p) => p.id == productId);
            } catch (_) {
              selectedProduct = spLine;
            }
            final sp = selectedProduct;
            final hasVariants = sp != null && sp.availableColors.isNotEmpty;
            final isGeogrid = sp?.category.any((c) => c.toLowerCase().contains('geogrid')) ?? false;
            if (hasVariants) {
              final p = sp;
              if (selectedColor == null || !p.availableColors.contains(selectedColor)) {
                selectedColor = p.availableColors.first;
              }
            } else {
              selectedColor = null;
            }
            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              constraints: const BoxConstraints(maxWidth: 420),
              title: Text(l10n.editStock),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      KeyedSubtree(
                        key: ValueKey<String>('edit-stock-product-field-$productId'),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: l10n.product,
                            border: const OutlineInputBorder(),
                            suffixIcon: Icon(Icons.arrow_drop_down, size: 24, color: theme.iconTheme.color),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          ),
                          child: InkWell(
                            onTap: () async {
                              final id = await _pickStockProductForDialog(ctx, sortedProducts, productId);
                              if (id != null) {
                                setDialogState(() {
                                  productId = id;
                                  selectedColor = null;
                                });
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: sp != null
                                    ? Text(
                                        sp.displayName(ctx),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.2),
                                      )
                                    : Text('—', style: TextStyle(color: Colors.grey[600])),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        key: ValueKey<String>('edit-stock-store-$storeId'),
                        initialValue: storeId,
                        decoration: InputDecoration(labelText: l10n.store, border: const OutlineInputBorder()),
                        items: _stores.map((s) => DropdownMenuItem(value: s.id, child: Text(s.displayName(context)))).toList(),
                        onChanged: (v) => setDialogState(() => storeId = v),
                      ),
                      if (hasVariants) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          key: ValueKey<String>('edit-stock-variant-$productId-$selectedColor'),
                          initialValue: selectedColor,
                          decoration: InputDecoration(
                            labelText: isGeogrid ? l10n.variant : l10n.color,
                            border: const OutlineInputBorder(),
                          ),
                          items: sp.availableColors
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(sp.displayOneColor(ctx, c)),
                                  ))
                              .toList(),
                          onChanged: (v) => setDialogState(() => selectedColor = v),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: qtyController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                        decoration: InputDecoration(
                          labelText: l10n.quantity,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
                FilledButton(
                  onPressed: () {
                    if (productId != null && storeId != null) {
                      final q = parseDecimalInput(qtyController.text);
                      if (q != null && q >= 0) Navigator.pop(ctx, true);
                    }
                  },
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        ),
      );
      if (saved == true) {
        qtyParsed = parseDecimalInput(qtyController.text);
      }
    } finally {
      qtyController.dispose();
    }
    if (saved != true || !mounted) return;

    final qty = qtyParsed ?? 0;
    productId ??= initialPid;
    storeId ??= initialSid;

    Product pForBody;
    try {
      pForBody = _products.firstWhere((p) => p.id == productId);
    } catch (_) {
      pForBody = spLine;
    }

    try {
      final body = <String, dynamic>{
        'quantity': qty,
        'productId': productId,
        'storeId': storeId,
      };
      if (pForBody.availableColors.isNotEmpty) {
        final sc = selectedColor?.trim();
        if (sc != null && sc.isNotEmpty) {
          body['variant'] = sc;
        }
      }
      await _apiService.put('/stock/${stock.id}', body);
      if (mounted) _loadStocks();
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        await _markStockNotificationsRead();
        if (!context.mounted) return;
        setState(() => _warehouseAddedByProductStore = {});
        if (!context.mounted) return;
        Navigator.of(context).pop(result);
      },
      child: Scaffold(
      appBar: AppBar(
        title: AppSearchBar(
          title: AppLocalizations.of(context)!.stockManagement,
          searchHint: AppLocalizations.of(context)!.searchStockHint,
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadStocks,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStock,
        child: const Icon(Icons.add),
      ),
    ),
    );
  }

  Widget _buildBody() {
    if (_loading && _stocks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _stocks.isEmpty) {
      return ConnectionErrorWidget(message: _error!, onRetry: _loadStocks);
    }
    if (_stocks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(AppLocalizations.of(context)!.noStockYet, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(AppLocalizations.of(context)!.tapToAddStock, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              FilledButton.icon(onPressed: _showAddStock, icon: const Icon(Icons.add), label: Text(AppLocalizations.of(context)!.addStock)),
            ],
          ),
        ),
      );
    }
    final items = _filteredStocks;
    if (items.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noStockMatchSearch));
    }
    final l10n = AppLocalizations.of(context)!;
    final totalDistinct = _distinctProductCount(_stocks);
    final filteredDistinct = _distinctProductCount(items);
    final hasSearch = _searchController.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.inventory_2_outlined, size: 22, color: Colors.teal.shade700),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.stockDistinctProductsCount(totalDistinct),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                      ),
                    ),
                    if (hasSearch) ...[
                      const SizedBox(height: 4),
                      Text(
                        l10n.stockSearchMatchCount(filteredDistinct),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
      onRefresh: _loadStocks,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final stock = items[index];
          final l10n = AppLocalizations.of(context)!;
          final manu = _resolvedManufacturer(stock);
          final whAdded = _warehouseAddedQtyFor(stock);
          final variantLabel = _variantLabelForList(context, stock);
          final productName = stock.product?.displayName(context) ?? '—';
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => _showStockDetails(stock),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CountBadge(
                          count: stock.quantity,
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          showShadow: false,
                          capAt99: false,
                          expandForLongCounts: true,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                productName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              if (variantLabel != null && variantLabel.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '${l10n.variant}: $variantLabel',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ),
                              ],
                              if (manu != null) ...[
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '${l10n.manufacturer}: $manu',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              if (stock.store != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${l10n.store}: ${stock.store!.displayName(context)}',
                                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                ),
                              ],
                              if (stock.product?.unit != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '${l10n.unit}: ${stock.product!.displayUnit(context)}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            if (value == 'display') {
                              _showStockDetails(stock);
                            } else if (value == 'edit') {
                              _updateQuantity(stock);
                            } else if (value == 'delete') {
                              _deleteStock(stock);
                            }
                          },
                          itemBuilder: (context) {
                            final l10n = AppLocalizations.of(context)!;
                            return [
                              PopupMenuItem(value: 'display', child: Row(children: [const Icon(Icons.visibility, size: 20), const SizedBox(width: 8), Text(l10n.display)])),
                              PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit, size: 20), const SizedBox(width: 8), Text(l10n.edit)])),
                              PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete, size: 20, color: Colors.red), const SizedBox(width: 8), Text(l10n.delete, style: const TextStyle(color: Colors.red))])),
                            ];
                          },
                        ),
                      ],
                    ),
                    if (whAdded > 0) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.notifications_active, size: 18, color: Colors.orange.shade800),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.warehouseStockAddedOnCard(whAdded.toString()),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
          ),
        ),
      ],
    );
  }
}

class _StockProductPickerSheet extends StatefulWidget {
  final List<Product> sortedProducts;
  final String? currentProductId;
  final Widget Function(BuildContext, Product) rowBuilder;

  const _StockProductPickerSheet({
    required this.sortedProducts,
    this.currentProductId,
    required this.rowBuilder,
  });

  @override
  State<_StockProductPickerSheet> createState() => _StockProductPickerSheetState();
}

class _StockProductPickerSheetState extends State<_StockProductPickerSheet> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filtered = _filterStockDialogProducts(widget.sortedProducts, _search.text);
    final maxH = math.min(560.0, MediaQuery.sizeOf(context).height * 0.72);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.product,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _search,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.searchProductsHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              height: maxH,
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n.noProductsMatchSearch,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final p = filtered[index];
                        final sel = p.id == widget.currentProductId;
                        return ListTile(
                          selected: sel,
                          title: widget.rowBuilder(context, p),
                          onTap: () => Navigator.pop(context, p.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
