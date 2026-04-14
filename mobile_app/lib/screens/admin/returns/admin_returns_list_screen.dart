import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/return_model.dart';
import '../../../models/store.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/embedded_ref_localized.dart';
import '../../../utils/l10n_ui_helpers.dart';
import '../../../utils/store_localized.dart';
import '../../../widgets/connection_error_widget.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_search_bar.dart';

class AdminReturnsListScreen extends StatefulWidget {
  const AdminReturnsListScreen({super.key});

  @override
  State<AdminReturnsListScreen> createState() => _AdminReturnsListScreenState();
}

class _AdminReturnsListScreenState extends State<AdminReturnsListScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<ReturnModel> _returns = [];
  List<Store> _stores = [];
  bool _loading = true;
  String? _error;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _loadReturns();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ReturnModel> get _filteredReturns {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _returns;
    return _returns.where((r) =>
        (r.project?.name.toLowerCase().contains(q) ?? false) ||
        (r.project?.nameAr?.toLowerCase().contains(q) ?? false) ||
        (r.user?.name.toLowerCase().contains(q) ?? false) ||
        (r.user?.nameAr?.toLowerCase().contains(q) ?? false) ||
        r.status.toLowerCase().contains(q)).toList();
  }

  Future<void> _loadReturns() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _apiService.get('/returns');
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _returns = (res['data'] as List)
              .map((e) => ReturnModel.fromJson(Map<String, dynamic>.from(e)))
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

  Future<void> _approveReturn(ReturnModel returnItem) async {
    if (_stores.isEmpty) {
      try {
        final res = await _apiService.get('/stores');
        if (res['success'] == true && res['data'] != null) {
          setState(() {
            _stores = (res['data'] as List).map((e) => Store.fromJson(Map<String, dynamic>.from(e))).toList();
          });
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
        return;
      }
    }
    if (_stores.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.noStoresAddFirst)));
      return;
    }
    String? storeId = _stores.first.id;
    final l10n = AppLocalizations.of(context)!;
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(l10n.approveReturn, style: AppTheme.appTextStyle(context, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.goodConditionReturnOrigin, style: AppTheme.appTextStyle(context, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Text(l10n.selectStoreDamagedFallback, style: AppTheme.appTextStyle(context, color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: storeId,
                decoration: InputDecoration(labelText: l10n.storeRequired, border: const OutlineInputBorder()),
                items: _stores.map((s) => DropdownMenuItem(value: s.id, child: Text(s.displayName(context)))).toList(),
                onChanged: (v) => setD(() => storeId = v),
              ),
              const SizedBox(height: 12),
              Text(l10n.goodStoreOriginDamagedSelected, style: AppTheme.appTextStyle(context, fontSize: 12, color: AppTheme.textTertiary)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.approve),
            ),
          ],
        ),
      ),
    );
    if (approved != true || !mounted) return;
    try {
      await _apiService.put('/returns/${returnItem.id}/approve', {'store': storeId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.returnApprovedUndamagedAdded), backgroundColor: AppTheme.success));
        await _loadReturns();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppTheme.error));
    }
  }

  void _showDetails(ReturnModel returnItem) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppTheme.textTertiary.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(
                returnItem.project != null ? l10n.returnWithProject(returnItem.project!.displayName(context)) : l10n.returnItem,
                style: AppTheme.appTextStyle(context, fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(localizedUiStatus(context, returnItem.status), style: const TextStyle(fontSize: 12)),
                backgroundColor: (returnItem.status == 'approved' ? AppTheme.success : returnItem.status == 'rejected' ? AppTheme.error : Colors.orange).withOpacity(0.2),
              ),
              if (returnItem.project != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(l10n.projectLabel(returnItem.project!.displayName(context)), style: AppTheme.appTextStyle(context, color: AppTheme.textSecondary))),
              if (returnItem.user != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.userLabel(localizedDisplayUserName(context, returnItem.user!.name, nameAr: returnItem.user!.nameAr)),
                    style: AppTheme.appTextStyle(context, color: AppTheme.textSecondary),
                  ),
                ),
              const SizedBox(height: 16),
              Text(l10n.productsLabel, style: AppTheme.appTextStyle(context, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              ...returnItem.products.map((p) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(formatReturnProductLine(context, productName: p.productName, quantity: p.quantity, condition: p.condition, color: p.color), style: AppTheme.appTextStyle(context, color: AppTheme.textSecondary)),
                  )),
              if (returnItem.notes != null && returnItem.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.notesLabel(returnItem.notes!), style: AppTheme.appTextStyle(context, color: AppTheme.textSecondary)),
              ],
              if (returnItem.status == 'pending') ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _approveReturn(returnItem);
                    },
                    icon: const Icon(Icons.check_circle),
                    label: Text(l10n.approveAddUndamagedWarehouse),
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: AppSearchBar(
          title: AppLocalizations.of(context)!.returns,
          searchHint: AppLocalizations.of(context)!.searchReturnsHint,
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
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loading ? null : _loadReturns),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _returns.isEmpty) return Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_error != null && _returns.isEmpty) {
      return ConnectionErrorWidget(message: _error!, onRetry: _loadReturns);
    }
    if (_returns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.undo_rounded, size: 64, color: AppTheme.textTertiary),
            const SizedBox(height: AppTheme.spaceMd),
            Text(AppLocalizations.of(context)!.noReturnsYet, style: AppTheme.appTextStyle(context, fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.returnsFromUsersAppear, style: AppTheme.appTextStyle(context, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }
    final items = _filteredReturns;
    if (items.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context)!.noReturnsMatch, style: AppTheme.appTextStyle(context, color: AppTheme.textSecondary)),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadReturns,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final r = items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
            child: AppCard(
              onTap: () => _showDetails(r),
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (r.status == 'approved' ? AppTheme.success : r.status == 'rejected' ? AppTheme.error : Colors.orange).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Center(
                      child: Icon(r.status == 'approved' ? Icons.check : r.status == 'rejected' ? Icons.close : Icons.pending, color: r.status == 'approved' ? AppTheme.success : r.status == 'rejected' ? AppTheme.error : Colors.orange, size: 24),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.project?.displayName(context) ?? AppLocalizations.of(context)!.returnItem, style: AppTheme.appTextStyle(context, fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        if (r.user != null)
                          Text(
                            localizedDisplayUserName(context, r.user!.name, nameAr: r.user!.nameAr),
                            style: AppTheme.appTextStyle(context, fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        if (r.products.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            formatReturnListPreview(context, r.products),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.appTextStyle(context, fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(localizedUiStatus(context, r.status), style: AppTheme.appTextStyle(context, fontSize: 12, color: AppTheme.textTertiary)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
