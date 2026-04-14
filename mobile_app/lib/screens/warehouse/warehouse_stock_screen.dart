import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/product.dart';
import '../../../models/stock.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/decimal_input.dart';
import '../../../utils/product_localized.dart';
import '../../../utils/store_localized.dart';
import '../../../widgets/app_search_bar.dart';
import '../../../widgets/connection_error_widget.dart';
import '../../../widgets/count_badge.dart';

class WarehouseStockScreen extends StatefulWidget {
  const WarehouseStockScreen({super.key});

  @override
  State<WarehouseStockScreen> createState() => _WarehouseStockScreenState();
}

class _WarehouseStockScreenState extends State<WarehouseStockScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<Stock> _stocks = [];
  List<Product> _products = [];
  bool _loading = true;
  String? _error;
  bool _showSearch = false;

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

  List<Stock> get _filteredStocks {
    final q = _searchController.text.trim().toLowerCase();
    final list = q.isEmpty
        ? List<Stock>.from(_stocks)
        : _stocks.where((s) {
              final p = s.product;
              final nameMatch = p != null &&
                  (productNameMatchesSearchQuery(p.name, null, q) ||
                      (p.nameAr?.toLowerCase().contains(q) ?? false));
              final catMatch = p != null &&
                  p.categories.any((c) => c.toLowerCase().contains(q));
              final manu = _resolvedManufacturer(s)?.toLowerCase() ?? '';
              return nameMatch ||
                  (manu.isNotEmpty && manu.contains(q)) ||
                  (s.store?.name.toLowerCase().contains(q) ?? false) ||
                  (s.store?.nameAr?.toLowerCase().contains(q) ?? false) ||
                  catMatch;
            }).toList();
    list.sort((a, b) => (a.product?.name ?? '').toLowerCase().compareTo((b.product?.name ?? '').toLowerCase()));
    return list;
  }

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

  Future<void> _loadStocks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _apiService.get('/stock'),
        _apiService.get('/products'),
      ]);
      final res = results[0];
      final productsRes = results[1];
      var products = List<Product>.from(_products);
      if (productsRes['success'] == true && productsRes['data'] != null) {
        products = (productsRes['data'] as List)
            .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _stocks = (res['data'] as List)
              .map((e) => Stock.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _products = products;
          _loading = false;
        });
      } else {
        setState(() {
          _products = products;
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

  Future<Product?> _fetchProduct(String productId) async {
    try {
      final res = await _apiService.get('/products/$productId');
      if (res['success'] == true && res['data'] != null) {
        return Product.fromJson(Map<String, dynamic>.from(res['data']));
      }
    } catch (_) {}
    return null;
  }

  void _showProductDetails(Product product) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radius2xl)),
          ),
          child: SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                    decoration: BoxDecoration(
                      color: AppTheme.textTertiary.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  product.displayName(context),
                  style: AppTheme.appTextStyle(context, fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text(
                    product.status.toLowerCase() == 'active' ? l10n.active : l10n.inactive,
                    style: AppTheme.appTextStyle(context, fontSize: 12),
                  ),
                  backgroundColor: product.status == 'active' ? AppTheme.success.withOpacity(0.2) : AppTheme.textTertiary.withOpacity(0.2),
                ),
                const SizedBox(height: AppTheme.spaceLg),
                _detailRow(l10n.category, product.category.isNotEmpty ? product.displayCategories(context) : '-'),
                if (product.manufacturer != null && product.manufacturer!.trim().isNotEmpty)
                  _detailRow(l10n.manufacturer, product.manufacturer!.trim()),
                if (product.availableColors.isNotEmpty)
                  _detailRow(l10n.availableColors, product.displayVariantTokens(context)),
                _detailRow(l10n.unit, product.displayUnit(context)),
                if (product.distributor != null && product.distributor!.isNotEmpty)
                  _detailRow(l10n.distributor, product.distributor!),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.appTextStyle(context, fontSize: 12, color: AppTheme.textTertiary)),
          Text(value, style: AppTheme.appTextStyle(context, fontSize: 14, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Future<void> _addQuantity(Stock stock) async {
    final productId = stock.product?.id;
    final storeId = stock.store?.id;
    if (productId == null || storeId == null) return;
    final qtyController = TextEditingController(text: '1');
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.addQuantityFor(stock.product?.displayName(context) ?? '')),
          content: TextField(
            controller: qtyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.quantityToAdd,
              border: const OutlineInputBorder(),
              hintText: '> 0',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () {
                final q = parseDecimalInput(qtyController.text);
                if (q != null && q > 0) Navigator.pop(ctx, true);
              },
              child: Text(l10n.add),
            ),
          ],
        );
      },
    );
    if (added != true || !mounted) return;
    final qty = parseDecimalInput(qtyController.text) ?? 0;
    if (qty <= 0) return;
    try {
      await _apiService.post('/stock', {
        'productId': productId,
        'storeId': storeId,
        'quantity': qty,
        'mode': 'add',
        if (stock.variant != null && stock.variant!.isNotEmpty) 'variant': stock.variant,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.quantityAddedSuccess), backgroundColor: Colors.green),
        );
        _loadStocks();
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppSearchBar(
          title: AppLocalizations.of(context)!.stock,
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
          child: Text(
            AppLocalizations.of(context)!.noStockYet,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final items = _filteredStocks;
    if (items.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noStockMatchSearch, textAlign: TextAlign.center));
    }
    return RefreshIndicator(
      onRefresh: _loadStocks,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final stock = items[index];
          final l10n = AppLocalizations.of(context)!;
          final manu = _resolvedManufacturer(stock);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CountBadge(
                count: stock.quantity,
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                showShadow: false,
                capAt99: false,
              ),
              title: Text(
                stock.product != null
                    ? stock.product!.titleWithOptionalColor(context, stock.variant)
                    : '—',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (manu != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${l10n.manufacturer}: $manu',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[800],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (stock.store != null)
                    Text(
                      '${l10n.store}: ${stock.store!.displayName(context)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  if (stock.product?.unit != null)
                    Text(
                      '${l10n.unit}: ${stock.product!.displayUnit(context)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  final productId = stock.product?.id;
                  if (productId == null) return;
                  if (value == 'view') {
                    final product = await _fetchProduct(productId);
                    if (product != null && mounted) _showProductDetails(product);
                    else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocalizations.of(context)!.couldNotLoadProduct)),
                      );
                    }
                  } else if (value == 'add') {
                    await _addQuantity(stock);
                  }
                },
                itemBuilder: (context) {
                  final l10n = AppLocalizations.of(context)!;
                  return [
                    PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          const Icon(Icons.visibility_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(l10n.viewProduct),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'add',
                      child: Row(
                        children: [
                          const Icon(Icons.add_circle_outline, size: 20),
                          const SizedBox(width: 8),
                          Text(l10n.addStock),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
