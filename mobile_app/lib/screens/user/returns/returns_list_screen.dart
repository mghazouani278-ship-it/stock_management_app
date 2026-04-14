import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/return_model.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/connection_error_widget.dart';
import '../../../widgets/app_card.dart';
import '../../../utils/l10n_ui_helpers.dart';
import '../../../utils/embedded_ref_localized.dart';
import '../../../utils/product_localized.dart';
import 'return_form_screen.dart';

class ReturnsListScreen extends StatefulWidget {
  const ReturnsListScreen({super.key});

  @override
  State<ReturnsListScreen> createState() => _ReturnsListScreenState();
}

class _ReturnsListScreenState extends State<ReturnsListScreen> {
  final ApiService _apiService = ApiService();
  final _searchController = TextEditingController();
  List<ReturnModel> _returns = [];
  bool _loading = true;
  String? _error;
  bool _searchVisible = false;

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
    final q = _searchController.text.toLowerCase().trim();
    if (q.isEmpty) return _returns;
    return _returns.where((r) {
      final matchStatus = r.status.toLowerCase().contains(q);
      final matchProject = (r.project?.name.toLowerCase().contains(q) ?? false) ||
          (r.project?.nameAr?.toLowerCase().contains(q) ?? false);
      final matchProducts = r.products.any(
        (p) => productNameMatchesSearchQuery(p.productName, p.product, q),
      );
      final matchNotes = r.notes?.toLowerCase().contains(q) ?? false;
      return matchStatus || matchProject || matchProducts || matchNotes;
    }).toList();
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

  void _showReturnDetails(ReturnModel returnItem) {
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
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiary.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                returnItem.project != null
                    ? AppLocalizations.of(context)!.returnWithProject(returnItem.project!.displayName(context))
                    : AppLocalizations.of(context)!.returnItem,
                style: AppTheme.appTextStyle(context, fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              _buildStatusChip(returnItem.status),
              if (returnItem.project != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(AppLocalizations.of(context)!.projectLabel(returnItem.project!.displayName(context)), style: AppTheme.appTextStyle(context, color: AppTheme.textSecondary)),
                ),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context)!.productsLabel, style: AppTheme.appTextStyle(context, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              ...returnItem.products.map((p) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      formatReturnProductLine(
                        context,
                        productName: p.productName,
                        quantity: p.quantity,
                        condition: p.condition,
                        color: p.color,
                      ),
                      style: AppTheme.appTextStyle(context, color: AppTheme.textSecondary),
                    ),
                  )),
              if (returnItem.notes != null && returnItem.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context)!.notesLabel(returnItem.notes!), style: AppTheme.appTextStyle(context, color: AppTheme.textSecondary)),
              ],
              if (returnItem.approvedBy != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    AppLocalizations.of(context)!.approvedByLabel(
                      localizedDisplayUserName(context, returnItem.approvedBy!.name, nameAr: returnItem.approvedBy!.nameAr),
                    ),
                    style: AppTheme.appTextStyle(context, fontSize: 12, color: AppTheme.textTertiary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'approved':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }
    return Chip(
      label: Text(localizedUiStatus(context, status), style: const TextStyle(fontSize: 12)),
      backgroundColor: color.withOpacity(0.2),
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
                  hintText: AppLocalizations.of(context)!.searchReturnsHint,
                  hintStyle: AppTheme.appTextStyle(context, color: AppTheme.textSecondary),
                  border: InputBorder.none,
                ),
                cursorColor: AppTheme.primary,
                onSubmitted: (_) => setState(() {}),
              )
            : Text(AppLocalizations.of(context)!.myReturns, style: AppTheme.appTextStyle(context, fontWeight: FontWeight.w600)),
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
            onPressed: _loading ? null : _loadReturns,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const ReturnFormScreen()),
          );
          if (added == true && mounted) await _loadReturns();
        },
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _returns.isEmpty) {
      return Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_error != null && _returns.isEmpty) {
      return ConnectionErrorWidget(message: _error!, onRetry: _loadReturns);
    }
    if (_returns.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.undo_rounded, size: 64, color: AppTheme.textTertiary),
              const SizedBox(height: AppTheme.spaceMd),
              Text(
                AppLocalizations.of(context)!.noReturnsYet,
                textAlign: TextAlign.center,
                style: AppTheme.appTextStyle(context, fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.returnsEmptySubtitle,
                textAlign: TextAlign.center,
                style: AppTheme.appTextStyle(context, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }
    final filtered = _filteredReturns;
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
      onRefresh: _loadReturns,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final returnItem = filtered[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
            child: AppCard(
              onTap: () => _showReturnDetails(returnItem),
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getStatusColor(returnItem.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Center(
                      child: Icon(returnItem.status == 'approved' ? Icons.check : returnItem.status == 'rejected' ? Icons.close : Icons.pending, color: _getStatusColor(returnItem.status), size: 24),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          returnItem.project?.displayName(context) ?? AppLocalizations.of(context)!.returnItem,
                          style: AppTheme.appTextStyle(context, fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                        if (returnItem.products.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            formatReturnListPreview(context, returnItem.products),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.appTextStyle(context, fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          localizedUiStatus(context, returnItem.status),
                          style: AppTheme.appTextStyle(context, fontSize: 12, color: AppTheme.textSecondary),
                        ),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}
