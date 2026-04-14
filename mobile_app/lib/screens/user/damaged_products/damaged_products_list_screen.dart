import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/damaged_product.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/connection_error_widget.dart';
import '../../../widgets/app_card.dart';
import '../../../utils/l10n_ui_helpers.dart';
import '../../../utils/store_localized.dart';
import '../../../utils/product_localized.dart';

class DamagedProductsListScreen extends StatefulWidget {
  const DamagedProductsListScreen({super.key});

  @override
  State<DamagedProductsListScreen> createState() => _DamagedProductsListScreenState();
}

class _DamagedProductsListScreenState extends State<DamagedProductsListScreen> {
  final ApiService _apiService = ApiService();
  final _searchController = TextEditingController();
  List<DamagedProduct> _items = [];
  bool _loading = true;
  String? _error;
  bool _searchVisible = false;

  @override
  void initState() {
    super.initState();
    _loadDamagedProducts();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DamagedProduct> get _filteredItems {
    final q = _searchController.text.toLowerCase().trim();
    if (q.isEmpty) return _items;
    return _items.where((i) {
      final matchProduct = productNameMatchesSearchQuery(i.product?.name, null, q);
      final matchProject = (i.project?.name.toLowerCase().contains(q) ?? false) ||
          (i.project?.nameAr?.toLowerCase().contains(q) ?? false);
      final matchStore = (i.store?.name.toLowerCase().contains(q) ?? false) ||
          (i.store?.nameAr?.toLowerCase().contains(q) ?? false);
      final matchReason = i.reason.toLowerCase().contains(q);
      final matchStatus = i.status.toLowerCase().contains(q);
      final matchNotes = i.notes?.toLowerCase().contains(q) ?? false;
      return matchProduct || matchProject || matchStore || matchReason || matchStatus || matchNotes;
    }).toList();
  }

  Future<void> _loadDamagedProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _apiService.get('/damaged-products');
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _items = (res['data'] as List)
              .map((e) => DamagedProduct.fromJson(Map<String, dynamic>.from(e)))
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

  void _showDetails(DamagedProduct item) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
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
                  item.product != null ? localizedApiProductName(context, item.product!.name) : l10n.damagedProduct,
                  style: AppTheme.appTextStyle(context, fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                _buildStatusChip(item.status),
                Padding(
                  padding: const EdgeInsets.only(top: AppTheme.spaceSm),
                  child: Text('${l10n.quantityLabel} ${item.quantity}', style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary)),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${l10n.reasonLabel} ${localizedDamageReason(context, item.reason)}', style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary)),
                ),
                if (item.store != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${l10n.storeLabel} ${item.store!.displayName(context)}',
                      style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary),
                    ),
                  ),
                if (item.project != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.projectLabel(item.project!.displayName(context)),
                      style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary),
                    ),
                  ),
                if (item.notes != null && item.notes!.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spaceMd),
                  Text(
                    l10n.notesLabel(localizedDamagedNotes(context, item.notes)),
                    style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary),
                  ),
                ],
                if (item.approvedBy != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTheme.spaceMd),
                    child: Text(
                      l10n.approvedByLabel(localizedDisplayUserName(context, item.approvedBy!.name, nameAr: item.approvedBy!.nameAr)),
                      style: AppTheme.appTextStyle(context, fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(localizedUiStatus(context, status), style: AppTheme.appTextStyle(context, fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: _searchVisible
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.searchDamagedHint,
                  hintStyle: AppTheme.appTextStyle(context, color: AppTheme.textSecondary),
                  border: InputBorder.none,
                ),
                cursorColor: AppTheme.primary,
                onSubmitted: (_) => setState(() {}),
              )
            : Text(AppLocalizations.of(context)!.damagedProducts, style: AppTheme.appTextStyle(context, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: Icon(_searchVisible ? Icons.close : Icons.search_rounded),
            onPressed: () {
              setState(() {
                _searchVisible = !_searchVisible;
                if (!_searchVisible) _searchController.clear();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _loadDamagedProducts,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_error != null && _items.isEmpty) {
      return ConnectionErrorWidget(message: _error!, onRetry: _loadDamagedProducts);
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, size: 64, color: AppTheme.textTertiary),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              AppLocalizations.of(context)!.noDamagedProductsReportedYet,
              textAlign: TextAlign.center,
              style: AppTheme.appTextStyle(context, fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.yourDamagedReportsWillAppear,
              textAlign: TextAlign.center,
              style: AppTheme.appTextStyle(context, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }
    final filtered = _filteredItems;
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noResultsFor(_searchController.text),
          textAlign: TextAlign.center,
          style: AppTheme.appTextStyle(context, color: AppTheme.textSecondary),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadDamagedProducts,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final item = filtered[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
            child: AppCard(
              onTap: () => _showDetails(item),
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getStatusColor(item.status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: _getStatusColor(item.status),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.product != null
                              ? localizedApiProductName(context, item.product!.name)
                              : AppLocalizations.of(context)!.product,
                          style: AppTheme.appTextStyle(context, fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(context)!.qtyReasonStatusLine(
                            '${item.quantity}',
                            localizedDamageReason(context, item.reason),
                            localizedUiStatus(context, item.status),
                          ),
                          style: AppTheme.appTextStyle(context, fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return AppTheme.success;
      case 'rejected':
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }
}
