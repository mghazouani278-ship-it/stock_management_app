import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/product.dart';
import '../../../providers/locale_provider.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/product_localized.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_search_bar.dart';
import '../../../widgets/connection_error_widget.dart';
import 'product_form_screen.dart';

class ProductsListScreen extends StatefulWidget {
  const ProductsListScreen({super.key});

  @override
  State<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends State<ProductsListScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<Product> _products = [];
  bool _loading = true;
  String? _error;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _filteredProducts(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _products;
    return _products.where((p) {
      if (p.name.toLowerCase().contains(query)) return true;
      final ar = p.nameAr?.toLowerCase() ?? '';
      if (ar.isNotEmpty && ar.contains(query)) return true;
      if (arabicLiteralProductNameFromString(p.name).toLowerCase().contains(query)) return true;
      if (englishLiteralProductNameFromString(p.name).toLowerCase().contains(query)) return true;
      final displayAr = arabicDisplayNameForProduct(p).toLowerCase();
      final displayEn = englishDisplayNameForProduct(p).toLowerCase();
      if (displayAr.contains(query) || displayEn.contains(query)) return true;
      if (p.category.isNotEmpty) {
        final catLoc = p.displayCategories(context).toLowerCase();
        if (catLoc.contains(query)) return true;
      }
      final m = p.manufacturer?.trim().toLowerCase() ?? '';
      if (m.isNotEmpty && m.contains(query)) return true;
      return p.category.any((c) => c.toLowerCase().contains(query));
    }).toList();
  }

  /// Ordre d’affichage selon la langue (sans muter la liste chargée depuis l’API).
  List<Product> _orderedForDisplay(BuildContext context, List<Product> list) {
    final isAr = Provider.of<LocaleProvider>(context, listen: false).isArabic;
    final copy = List<Product>.from(list);
    copy.sort((a, b) {
      if (isAr) {
        return arabicDisplayNameForProduct(a).compareTo(arabicDisplayNameForProduct(b));
      }
      return englishDisplayNameForProduct(a).toLowerCase().compareTo(englishDisplayNameForProduct(b).toLowerCase());
    });
    return copy;
  }

  TextStyle _listTextStyle(BuildContext context, {double fontSize = 14, FontWeight? weight, Color? color, FontStyle? fontStyle}) {
    final theme = Theme.of(context).textTheme.bodyMedium;
    return (theme ?? const TextStyle()).copyWith(
      fontSize: fontSize,
      fontWeight: weight ?? FontWeight.normal,
      color: color ?? AppTheme.textSecondary,
      fontStyle: fontStyle,
    );
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _apiService.get('/products');
      if (res['success'] == true && res['data'] != null) {
        if (!mounted) return;
        setState(() {
          _products = (res['data'] as List)
              .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
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

  void _showProductDetails(Product product) {
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: _buildProductThumbnail(product, size: 64),
                    ),
                    const SizedBox(width: AppTheme.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.displayName(context),
                            style: _listTextStyle(context, fontSize: 18, weight: FontWeight.w600, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Chip(
                            label: Text(
                              product.status == 'active'
                                  ? AppLocalizations.of(context)!.active
                                  : AppLocalizations.of(context)!.inactive,
                              style: _listTextStyle(context, fontSize: 12),
                            ),
                            backgroundColor: product.status == 'active' ? AppTheme.success.withOpacity(0.2) : AppTheme.textTertiary.withOpacity(0.2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceLg),
                _detailRow(AppLocalizations.of(context)!.category, product.category.isNotEmpty ? product.displayCategories(context) : '-'),
                _detailRow(
                  AppLocalizations.of(context)!.manufacturer,
                  (product.manufacturer != null && product.manufacturer!.trim().isNotEmpty) ? product.manufacturer!.trim() : '-',
                ),
                if (product.availableColors.isNotEmpty)
                  _detailRow(AppLocalizations.of(context)!.availableColors, product.displayVariantTokens(context)),
                _detailRow(AppLocalizations.of(context)!.unit, product.displayUnit(context)),
                if (product.distributor != null && product.distributor!.isNotEmpty)
                  _detailRow(AppLocalizations.of(context)!.distributor, product.distributor!),
                if (product.stores != null && product.stores!.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spaceSm),
                  Text(AppLocalizations.of(context)!.storesDepots, style: _listTextStyle(context, fontSize: 14, weight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  ...product.stores!.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('  • ${s.store}: ${s.quantity}', style: _listTextStyle(context, fontSize: 14)),
                      )),
                ],
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
          Text(label, style: _listTextStyle(context, fontSize: 12, color: AppTheme.textTertiary)),
          Text(value, style: _listTextStyle(context, fontSize: 14, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(Product product) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: Text(l10n.deleteProduct, style: _listTextStyle(context, fontSize: 18, weight: FontWeight.w600, color: AppTheme.textPrimary)),
        content: Text(l10n.confirmDeleteItem(product.displayName(context)), style: _listTextStyle(context)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel, style: _listTextStyle(context))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: AppTheme.error), child: Text(l10n.delete, style: _listTextStyle(context, weight: FontWeight.w600))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _apiService.delete('/products/${product.id}');
      if (mounted) _loadProducts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: AppSearchBar(
          title: AppLocalizations.of(context)!.products,
          searchHint: AppLocalizations.of(context)!.searchProductsHint,
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
            iconSize: 24,
            icon: const Icon(Icons.refresh_rounded, size: 24),
            onPressed: _loading ? null : _loadProducts,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const ProductFormScreen()),
          );
          if (added == true && mounted) _loadProducts();
        },
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  String _getImageUrl(Product product) {
    final img = product.image;
    if (img == null || img.isEmpty) return '';
    String filename = '';
    if (img.contains('/uploads/')) {
      filename = img.split('/uploads/').last.split('?').first;
    } else if (img.startsWith('/')) {
      filename = img.replaceFirst('/', '');
    } else {
      filename = img;
    }
    if (filename.isEmpty) return '';
    return '${ApiService.baseUrl}/uploads/$filename';
  }

  Widget _buildProductThumbnail(Product product, {double size = 56}) {
    final url = _getImageUrl(product);
    if (url.isEmpty) {
      return Icon(
        Icons.inventory_2_rounded,
        size: size * 0.55,
        color: product.status == 'active' ? AppTheme.success : AppTheme.textTertiary,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Image.network(
        url,
        fit: BoxFit.cover,
        width: size,
        height: size,
        gaplessPlayback: true,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: size,
            height: size,
            color: AppTheme.surfaceVariant.withOpacity(0.5),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))),
          );
        },
        errorBuilder: (_, __, ___) => Icon(
          Icons.inventory_2_rounded,
          size: size * 0.55,
          color: product.status == 'active' ? AppTheme.success : AppTheme.textTertiary,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _products.isEmpty) {
      return Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_error != null && _products.isEmpty) {
      return ConnectionErrorWidget(message: _error!, onRetry: _loadProducts);
    }
    if (_products.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_rounded, size: 64, color: AppTheme.textTertiary),
            const SizedBox(height: AppTheme.spaceMd),
            Text(l10n.noProductsYet, style: _listTextStyle(context, fontSize: 18, weight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(l10n.tapToAddFirstProduct, style: _listTextStyle(context)),
          ],
        ),
      );
    }
    if (_filteredProducts(context).isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: AppTheme.textTertiary),
            const SizedBox(height: AppTheme.spaceMd),
            Text(l10n.noProductsMatchSearch, style: _listTextStyle(context, fontSize: 18, weight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(l10n.tryDifferentSearch, style: _listTextStyle(context)),
          ],
        ),
      );
    }
    final productsToShow = _orderedForDisplay(context, _filteredProducts(context));
    final l10n = AppLocalizations.of(context)!;
    return RefreshIndicator(
      onRefresh: _loadProducts,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(AppTheme.spaceSm, AppTheme.spaceMd, AppTheme.spaceSm, 80),
        itemCount: productsToShow.length,
        itemBuilder: (context, index) {
          final product = productsToShow[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
            child: AppCard(
              onTap: () => _openProductEditor(product),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: ColoredBox(
                      color: (product.status == 'active' ? AppTheme.success : AppTheme.textTertiary).withOpacity(0.12),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Center(child: _buildProductThumbnail(product, size: 56)),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.displayName(context),
                          style: _listTextStyle(context, fontSize: 15, weight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                        if (product.category.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            child: Text(
                              product.displayCategories(context),
                              style: _listTextStyle(context, fontSize: 12),
                            ),
                          ),
                        ],
                        if (product.manufacturer != null && product.manufacturer!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${l10n.manufacturer}: ${product.manufacturer!.trim()}',
                            style: _listTextStyle(context, fontSize: 12, color: AppTheme.textSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (product.availableColors.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            product.displayVariantTokens(context),
                            style: _listTextStyle(context, fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(product.displayUnit(context), style: _listTextStyle(context, fontSize: 13)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: product.status == 'active' ? AppTheme.success : AppTheme.textTertiary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              product.status == 'active' ? l10n.active : l10n.inactive,
                              style: _listTextStyle(
                                context,
                                fontSize: 12,
                                color: product.status == 'active' ? AppTheme.success : AppTheme.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                    onSelected: (value) async {
                      if (value == 'display') {
                        _showProductDetails(product);
                      } else if (value == 'edit') {
                        await _openProductEditor(product);
                      } else if (value == 'delete') {
                        await _deleteProduct(product);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'display',
                        child: Row(
                          children: [
                            const Icon(Icons.visibility_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(AppLocalizations.of(ctx)!.display, style: _listTextStyle(ctx, fontSize: 13)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(AppLocalizations.of(ctx)!.edit, style: _listTextStyle(ctx, fontSize: 13)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_rounded, color: AppTheme.error, size: 18),
                            const SizedBox(width: 8),
                            Text(AppLocalizations.of(ctx)!.delete, style: _listTextStyle(ctx, fontSize: 13, color: AppTheme.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openProductEditor(Product product) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    );
    if (updated == true && mounted) await _loadProducts();
  }
}
