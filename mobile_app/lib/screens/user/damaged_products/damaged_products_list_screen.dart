import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/damaged_product.dart';
import '../../../models/product.dart';
import '../../../models/user.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/roles.dart';
import '../../../widgets/connection_error_widget.dart';
import '../../../widgets/app_card.dart';
import '../../../utils/l10n_ui_helpers.dart';
import '../../../utils/product_localized.dart';
import '../../../utils/project_localized.dart';
import '../../../utils/store_localized.dart';

class DamagedProductsListScreen extends StatefulWidget {
  const DamagedProductsListScreen({super.key});

  @override
  State<DamagedProductsListScreen> createState() => _DamagedProductsListScreenState();
}

class _DamagedProductsListScreenState extends State<DamagedProductsListScreen> {
  final ApiService _apiService = ApiService();
  final _searchController = TextEditingController();
  List<DamagedProduct> _items = [];
  List<Project> _projects = [];
  bool _loading = true;
  String? _error;
  bool _searchVisible = false;

  bool get _isSupervisor => isSupervisor(context.read<AuthProvider>().user?.role);

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
      final matchReason = i.reason.toLowerCase().contains(q);
      final matchStatus = i.status.toLowerCase().contains(q);
      final matchNotes = i.notes?.toLowerCase().contains(q) ?? false;
      return matchProduct || matchProject || matchReason || matchStatus || matchNotes;
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

  Future<void> _ensureLookups() async {
    if (_projects.isNotEmpty) return;
    final user = context.read<AuthProvider>().user;
    final res = await _apiService.get('/projects', queryParams: {'light': 'true', 'products': 'true'});
    if (res['success'] == true && res['data'] is List) {
      var projects = (res['data'] as List)
          .map((e) => Project.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (isSupervisor(user?.role)) {
        final allowed = user?.projectIds.toSet() ?? {};
        if (allowed.isNotEmpty) {
          projects = projects.where((p) => allowed.contains(p.id)).toList();
        }
      } else if (isUserRole(user?.role) && user?.project != null) {
        projects = projects.where((p) => p.id == user!.project!.id).toList();
        if (projects.isEmpty) projects = [user!.project!];
      }
      _projects = projects;
    }
  }

  List<Product> _productsForProject(Project? project) {
    if (project?.products == null) return const [];
    final seen = <String>{};
    final out = <Product>[];
    for (final pp in project!.products!) {
      final id = pp.product;
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      out.add(Product(
        id: id,
        name: (pp.productName != null && pp.productName!.trim().isNotEmpty) ? pp.productName! : id,
        category: const [],
        unit: 'pcs',
        status: 'active',
      ));
    }
    return out;
  }

  Future<void> _showAddForm() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await _ensureLookups();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
      return;
    }
    if (!mounted) return;
    if (_projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.addProductsStoresFirst)),
      );
      return;
    }

    String? projectId = _projects.first.id;
    var products = _productsForProject(_projects.first);
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.addProductsStoresFirst)),
      );
      return;
    }
    String? productId = products.first.id;
    // Damaged or not damaged (good)
    String condition = 'damaged';
    final qtyController = TextEditingController(text: '1');
    final notesController = TextEditingController();

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final dlgL10n = AppLocalizations.of(ctx)!;
          return AlertDialog(
            title: Text(dlgL10n.addDamagedProduct),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_projects.length > 1 || _isSupervisor) ...[
                    DropdownButtonFormField<String>(
                      value: projectId,
                      decoration: InputDecoration(
                        labelText: '${dlgL10n.project} *',
                        border: const OutlineInputBorder(),
                      ),
                      items: _projects
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.displayName(ctx)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setD(() {
                          projectId = v;
                          Project? proj;
                          for (final p in _projects) {
                            if (p.id == v) {
                              proj = p;
                              break;
                            }
                          }
                          products = _productsForProject(proj);
                          productId = products.isNotEmpty ? products.first.id : null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  DropdownButtonFormField<String>(
                    value: productId,
                    decoration: InputDecoration(
                      labelText: '${dlgL10n.product} *',
                      border: const OutlineInputBorder(),
                    ),
                    items: products
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.displayName(ctx)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setD(() => productId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: condition,
                    decoration: InputDecoration(
                      labelText: dlgL10n.conditionLabel,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'damaged',
                        child: Text(dlgL10n.damagedCondition),
                      ),
                      DropdownMenuItem(
                        value: 'good',
                        child: Text(dlgL10n.goodCondition),
                      ),
                    ],
                    onChanged: (v) => setD(() => condition = v ?? 'damaged'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '${dlgL10n.quantity} *',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: dlgL10n.notesOptional,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(dlgL10n.cancel)),
              FilledButton(
                onPressed: () {
                  if (productId != null &&
                      projectId != null &&
                      (int.tryParse(qtyController.text) ?? 0) > 0) {
                    Navigator.pop(ctx, true);
                  }
                },
                child: Text(dlgL10n.add),
              ),
            ],
          );
        },
      ),
    );

    if (added != true || !mounted) return;
    final reason = condition == 'good' ? 'Good condition' : 'Returned as damaged';
    try {
      await _apiService.post('/damaged-products', {
        'product': productId,
        'projectId': projectId,
        'quantity': int.parse(qtyController.text),
        'reason': reason,
        'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.damagedProductAdded), backgroundColor: Colors.green),
      );
      await _loadDamagedProducts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddForm,
        child: const Icon(Icons.add_rounded),
      ),
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
                        if (item.project != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.project!.displayName(context),
                            style: AppTheme.appTextStyle(context, fontSize: 12, color: AppTheme.textTertiary),
                          ),
                        ],
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
