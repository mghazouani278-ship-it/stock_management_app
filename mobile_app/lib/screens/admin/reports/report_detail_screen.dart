import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/user.dart';
import '../../../services/api_service.dart';
import '../../../utils/l10n_formatters.dart';
import '../../../utils/l10n_ui_helpers.dart';
import '../../../utils/product_localized.dart';
import '../../../utils/project_localized.dart';
import '../../../utils/project_report_pdf.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_search_bar.dart';
import '../../../widgets/connection_error_widget.dart';
import '../../../widgets/count_badge.dart';
import 'reports_screen.dart';
import 'report_type_l10n.dart';
import '../../../navigation/app_route_observer.dart';

class ReportDetailScreen extends StatefulWidget {
  final ReportType reportType;
  final bool allowDelete;

  const ReportDetailScreen({super.key, required this.reportType, this.allowDelete = true});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> with RouteAware {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _searchController.dispose();
    super.dispose();
  }

  /// Revient sur cet écran après une route poussée par-dessus (ex. autre écran puis retour).
  @override
  void didPopNext() {
    _loadReport();
  }

  List<dynamic> _filteredItems(BuildContext context) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((i) {
      final item = i as Map<String, dynamic>;
      final title = _getItemTitle(context, item).toLowerCase();
      final subtitle = _getItemSubtitle(context, item).toLowerCase();
      return title.contains(q) || subtitle.contains(q);
    }).toList();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.reportType == ReportType.projects) {
        final res = await _apiService.get(
          '/projects',
          queryParams: {
            'light': '1',
            '_': DateTime.now().millisecondsSinceEpoch.toString(),
          },
        );
        if (res['success'] == true && res['data'] != null) {
          setState(() {
            _items = List<dynamic>.from(res['data']);
            _loading = false;
          });
        } else {
          setState(() => _loading = false);
        }
        return;
      }
      // Validated Distributions: use main distributions API with status filter (more reliable)
      final String endpoint;
      final Map<String, String>? queryParams;
      if (widget.reportType == ReportType.distributions) {
        endpoint = '/distributions';
        queryParams = {'status': 'validated'};
      } else {
        endpoint = '/reports/${widget.reportType.endpoint}';
        queryParams = null;
      }
      final res = await _apiService.get(endpoint, queryParams: queryParams);
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _items = List<dynamic>.from(res['data']);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: AppSearchBar(
          title: widget.reportType.titleFull(l10n),
          searchHint: l10n.searchReportHint,
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
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _loadReport,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
    if (_loading && _items.isEmpty) {
      return Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_error != null && _items.isEmpty) {
      return ConnectionErrorWidget(message: _error!, onRetry: _loadReport);
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.reportType.icon, size: 64, color: AppTheme.textTertiary),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              l10n.noItemsFound(widget.reportType.titleFull(l10n)),
              textAlign: TextAlign.center,
              style: AppTheme.appTextStyle(context, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }
    final items = _filteredItems(context);
    if (items.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noItemsMatchSearch,
          style: AppTheme.appTextStyle(context, color: AppTheme.textSecondary),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadReport,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index] as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
            child: AppCard(
              onTap: () => _showItemDetails(item),
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: AppTheme.appTextStyle(context, 
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getItemTitle(context, item),
                          style: AppTheme.appTextStyle(context, 
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (widget.reportType == ReportType.projects)
                          _buildProjectListSubtitle(context, item)
                        else
                          Text(
                            _getItemSubtitle(context, item),
                            style: AppTheme.appTextStyle(context, 
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AppTheme.textTertiary),
                    padding: EdgeInsets.zero,
                    onSelected: (value) async {
                      if (value == 'details') {
                        _showItemDetails(item);
                      } else if (value == 'delete') {
                        await _deleteItem(item);
                      }
                    },
                    itemBuilder: (context) {
                      final l10n = AppLocalizations.of(context)!;
                      return [
                        PopupMenuItem(
                          value: 'details',
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 20),
                              const SizedBox(width: 12),
                              Text(l10n.viewDetails),
                            ],
                          ),
                        ),
                        if (widget.allowDelete && widget.reportType != ReportType.projects)
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete_outline, size: 20, color: AppTheme.error),
                                const SizedBox(width: 12),
                                Text(l10n.delete, style: const TextStyle(color: AppTheme.error)),
                            ],
                          ),
                        ),
                      ];
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getItemTitle(BuildContext context, Map<String, dynamic> item) {
    final l10n = AppLocalizations.of(context)!;
    switch (widget.reportType) {
      case ReportType.distributions:
        final project = item['project']?['name'];
        final store = item['store']?['name'];
        if (project != null && store != null) return '$project • $store';
        if (project != null) return project;
        if (store != null) return store;
        return '${l10n.distributionSingle}${item['project']?['name'] != null ? ' • ${item['project']['name']}' : ''}${item['store']?['name'] != null ? ' • ${item['store']['name']}' : ''}';
      case ReportType.orders:
        return '${l10n.order}${item['project']?['name'] != null ? ' • ${item['project']['name']}' : ''}${item['user']?['name'] != null ? ' • ${item['user']['name']}' : ''}';
      case ReportType.returns:
        return '${l10n.returnItem}${item['project']?['name'] != null ? ' • ${item['project']['name']}' : ''}${item['user']?['name'] != null ? ' • ${item['user']['name']}' : ''}';
      case ReportType.damagedProducts:
        final pn = item['product']?['name']?.toString();
        return pn != null && pn.isNotEmpty
            ? localizedApiProductName(context, pn)
            : l10n.damagedProduct;
      case ReportType.stockHistory:
        final ps = item['product']?['name']?.toString();
        return ps != null && ps.isNotEmpty
            ? localizedApiProductName(context, ps)
            : l10n.stockChange;
      case ReportType.projects:
        final proj = Project.fromJson(Map<String, dynamic>.from(item));
        final n = proj.displayName(context);
        return n.isNotEmpty ? n : l10n.project;
    }
  }

  String _getItemSubtitle(BuildContext context, Map<String, dynamic> item) {
    final l10n = AppLocalizations.of(context)!;
    switch (widget.reportType) {
      case ReportType.distributions:
        final project = item['project']?['name'];
        final store = item['store']?['name'];
        final createdStr = L10nFormatters.formatDateFromApi(context, item['createdAt']);
        final validatedStr = L10nFormatters.formatDateFromApi(context, item['validatedAt']);
        final distStr = L10nFormatters.formatDateFromApi(context, item['distributionDate']);
        final parts = <String>[];
        if (project != null) parts.add(project.toString());
        if (store != null) parts.add(store.toString());
        if (createdStr != null) parts.add('${l10n.createdDate} $createdStr');
        if (validatedStr != null) parts.add('${l10n.validatedDate} $validatedStr');
        if (distStr != null) parts.add('${l10n.distributionDateLabel} $distStr');
        return parts.join(' • ');
      case ReportType.orders:
        final user = item['user']?['name'];
        final project = item['project']?['name'];
        final createdStr = L10nFormatters.formatDateFromApi(context, item['createdAt']);
        final approvedStr = L10nFormatters.formatDateFromApi(context, item['approvedAt']);
        final distStr = L10nFormatters.formatDateFromApi(context, item['deliveryDate']);
        final parts = <String>[];
        if (user != null) parts.add(user.toString());
        if (project != null) parts.add(project.toString());
        if (createdStr != null) parts.add('${l10n.createdDate} $createdStr');
        if (approvedStr != null) parts.add('${l10n.approvedDate} $approvedStr');
        if (distStr != null) parts.add('${l10n.distributionDateLabel} $distStr');
        return parts.join(' • ');
      case ReportType.returns:
        final user = item['user']?['name'];
        final project = item['project']?['name'];
        final createdStr = L10nFormatters.formatDateFromApi(context, item['createdAt']);
        final approvedStr = L10nFormatters.formatDateFromApi(context, item['approvedAt']);
        final returnStr = L10nFormatters.formatDateFromApi(context, item['createdAt']);
        final parts = <String>[];
        if (user != null) parts.add(user.toString());
        if (project != null) parts.add(project.toString());
        if (createdStr != null) parts.add('${l10n.createdDate} $createdStr');
        if (approvedStr != null) parts.add('${l10n.approvedDate} $approvedStr');
        if (returnStr != null) parts.add('${l10n.returnDateByUser} $returnStr');
        return parts.join(' • ');
      case ReportType.damagedProducts:
        final productRaw = item['product']?['name']?.toString();
        final product = productRaw != null && productRaw.isNotEmpty
            ? localizedApiProductName(context, productRaw)
            : null;
        final qty = item['quantity'];
        final createdStr = L10nFormatters.formatDateFromApi(context, item['createdAt']);
        final approvedStr = L10nFormatters.formatDateFromApi(context, item['approvedAt']);
        final reportStr = L10nFormatters.formatDateFromApi(context, item['createdAt']);
        final parts = <String>[];
        if (product != null) parts.add(product.toString());
        parts.add('${l10n.qtyLabel} $qty');
        if (createdStr != null) parts.add('${l10n.createdDate} $createdStr');
        if (approvedStr != null) parts.add('${l10n.approvedDate} $approvedStr');
        if (reportStr != null) parts.add('${l10n.reportDateByUser} $reportStr');
        return parts.join(' • ');
      case ReportType.stockHistory:
        final type = item['type']?.toString() ?? '';
        final qty = item['quantity']?.toString() ?? '';
        final productCreatedAt = item['productCreatedAt'] ?? item['product']?['createdAt'];
        final dateStr = L10nFormatters.formatDateFromApi(context, productCreatedAt);
        if (dateStr != null) return '$type • $qty • ${l10n.createdDate} $dateStr';
        return '$type • $qty';
      case ReportType.projects:
        final proj = Project.fromJson(Map<String, dynamic>.from(item));
        final owner = proj.displayOwner(context);
        final createdStr = L10nFormatters.formatDateFromApi(context, item['createdAt']);
        final updatedStr = L10nFormatters.formatDateFromApi(context, item['updatedAt']);
        final lines = <String>[];
        if (owner != null && owner.isNotEmpty) lines.add(owner);
        if (createdStr != null) lines.add('${l10n.creationDate} $createdStr');
        if (updatedStr != null) lines.add('${l10n.projectLastEditDateLabel} $updatedStr');
        return lines.isEmpty ? l10n.reportProjects : lines.join('\n');
    }
  }

  List<String> _getProjectSubtitleLines(BuildContext context, Map<String, dynamic> item) {
    final l10n = AppLocalizations.of(context)!;
    final proj = Project.fromJson(Map<String, dynamic>.from(item));
    final owner = proj.displayOwner(context);
    final createdStr = L10nFormatters.formatDateFromApi(context, item['createdAt']);
    final updatedStr = L10nFormatters.formatDateFromApi(context, item['updatedAt']);
    final lines = <String>[];
    if (owner != null && owner.isNotEmpty) lines.add(owner);
    if (createdStr != null) lines.add('${l10n.creationDate} $createdStr');
    if (updatedStr != null) lines.add('${l10n.projectLastEditDateLabel} $updatedStr');
    return lines;
  }

  Widget _buildProjectListSubtitle(BuildContext context, Map<String, dynamic> item) {
    final l10n = AppLocalizations.of(context)!;
    final proj = Project.fromJson(Map<String, dynamic>.from(item));
    final owner = proj.displayOwner(context);
    final createdStr = L10nFormatters.formatDateFromApi(context, item['createdAt']) ?? '—';
    final updatedStr = L10nFormatters.formatDateFromApi(context, item['updatedAt']) ?? '—';
    final style = AppTheme.appTextStyle(
      context,
      fontSize: 13,
      color: AppTheme.textSecondary,
    );
    Widget dateMiniCard(String title, String value) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.textTertiary.withOpacity(0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.appTextStyle(
                  context,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: AppTheme.appTextStyle(
                  context,
                  fontSize: 12,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (owner != null && owner.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(owner, style: style),
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            dateMiniCard('1. ${l10n.creationDate.replaceAll(':', '')}', createdStr),
            const SizedBox(width: 8),
            dateMiniCard('2. ${l10n.projectLastEditDateLabel}', updatedStr),
          ],
        ),
      ],
    );
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    if (widget.reportType == ReportType.projects) return;
    final id = item['id'] ?? item['_id']?.toString();
    if (id == null || id.toString().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.cannotDeleteItem), backgroundColor: AppTheme.error),
        );
      }
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteQuestion),
        content: Text(l10n.deleteItemQuestion(widget.reportType.deleteTypeLabel(l10n))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      String endpoint;
      switch (widget.reportType) {
        case ReportType.distributions:
          endpoint = '/distributions/$id';
          break;
        case ReportType.orders:
          endpoint = '/orders/$id';
          break;
        case ReportType.returns:
          endpoint = '/returns/$id';
          break;
        case ReportType.damagedProducts:
          endpoint = '/damaged-products/$id';
          break;
        case ReportType.stockHistory:
          endpoint = '/reports/stock-history/$id';
          break;
        case ReportType.projects:
          return;
      }
      await _apiService.delete(endpoint);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.deletedSuccess), backgroundColor: AppTheme.success),
        );
        _loadReport();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showItemDetails(Map<String, dynamic> item) async {
    var effectiveItem = item;
    if (widget.reportType == ReportType.projects) {
      final id = item['id']?.toString();
      if (id != null && id.isNotEmpty) {
        try {
          final res = await _apiService.get('/projects/$id');
          if (res is Map && res['success'] == true && res['data'] is Map<String, dynamic>) {
            effectiveItem = Map<String, dynamic>.from(res['data']);
          }
        } catch (_) {
          // Keep lightweight data if detail fetch fails.
        }
      }
    }
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
                ..._formatItemDetails(context, effectiveItem),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatProjectProductLine(BuildContext context, ProjectProduct p) {
    final raw = p.productName ?? p.product;
    final name = raw.trim().isNotEmpty ? localizedApiProductName(context, raw) : raw;
    if (p.color != null && p.color!.isNotEmpty) {
      return '$name (${localizedVariantOrColorLabel(context, p.color!)})';
    }
    return name;
  }

  Widget _projectQtyChip(BuildContext context, String label, int value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color.withOpacity(0.95)),
        ),
        CountBadge(
          count: value,
          backgroundColor: color,
          foregroundColor: Colors.white,
          showShadow: false,
          capAt99: false,
        ),
      ],
    );
  }

  Widget _projectProductCard(BuildContext context, ProjectProduct p, AppLocalizations l10n) {
    final requested = p.requestedQuantity;
    final remaining = p.allowedQuantity;
    final distQty = requested - remaining < 0 ? 0 : requested - remaining;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      child: AppCard(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatProjectProductLine(context, p),
              style: AppTheme.appTextStyle(context, fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _projectQtyChip(context, l10n.requested, requested, Colors.blue),
                _projectQtyChip(context, l10n.distributed, distQty, Colors.green),
                _projectQtyChip(context, l10n.quantityRest, remaining, Colors.blueGrey),
                _projectQtyChip(context, l10n.supplementary, p.supplementaryQuantity, Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _formatProjectReportDetailWidgets(BuildContext context, Map<String, dynamic> item) {
    final l10n = AppLocalizations.of(context)!;
    final project = Project.fromJson(Map<String, dynamic>.from(item));
    final createdStr = L10nFormatters.formatDateFromApi(context, item['createdAt']);
    final updatedStr = L10nFormatters.formatDateFromApi(context, item['updatedAt']);
    final name = project.displayName(context);
    final desc = project.displayDescription(context);
    final owner = project.displayOwner(context);
    final history = (project.history ?? <ProjectHistory>[])
        .where((h) => h.at != null)
        .toList()
      ..sort((a, b) => b.at!.compareTo(a.at!));
    final hasCreated = history.any((h) => h.action.toLowerCase() == 'created');
    if (!hasCreated && project.createdAt != null) {
      history.add(ProjectHistory(action: 'created', at: project.createdAt, changes: const ['project']));
    }
    final hasUpdated = history.any((h) => h.action.toLowerCase() == 'updated');
    if (!hasUpdated &&
        project.updatedAt != null &&
        (project.createdAt == null || project.updatedAt!.isAfter(project.createdAt!))) {
      history.add(ProjectHistory(action: 'updated', at: project.updatedAt, changes: const ['project']));
    }
    history.sort((a, b) => a.at!.compareTo(b.at!));
    if (history.isEmpty) {
      if (project.createdAt != null) {
        history.add(ProjectHistory(action: 'created', at: project.createdAt, changes: const ['project']));
      }
      if (project.updatedAt != null &&
          (project.createdAt == null || project.updatedAt!.isAfter(project.createdAt!))) {
        history.add(ProjectHistory(action: 'updated', at: project.updatedAt, changes: const ['project']));
      }
      history.sort((a, b) => b.at!.compareTo(a.at!));
    }

    String _labelForProjectChange(String key) {
      switch (key) {
        case 'name':
          return l10n.project;
        case 'nameAr':
          return l10n.nameArOptional;
        case 'description':
          return l10n.description;
        case 'status':
          return l10n.status;
        case 'projectOwner':
          return l10n.projectOwner;
        case 'projectOwnerAr':
          return l10n.projectOwnerArabic;
        case 'boqCreationDate':
          return l10n.projectBoqCreationDateRequired;
        case 'products':
          return l10n.products;
        case 'project':
          return l10n.project;
        default:
          return key;
      }
    }
    final list = <Widget>[
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => ProjectReportPdf.export(context, Map<String, dynamic>.from(item)),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(l10n.reportExportProjectPdf),
        ),
      ),
      const SizedBox(height: AppTheme.spaceMd),
      Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
        child: Text('${l10n.project}: $name', style: AppTheme.appTextStyle(context, fontWeight: FontWeight.w600, fontSize: 17)),
      ),
      if (owner != null && owner.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
          child: Text('${l10n.owner}: $owner', style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary)),
        ),
      if (desc != null && desc.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
          child: Text('${l10n.description}: $desc', style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary)),
        ),
      Padding(
        padding: const EdgeInsets.only(top: AppTheme.spaceSm, bottom: AppTheme.spaceSm),
        child: Text(l10n.products, style: AppTheme.appTextStyle(context, fontWeight: FontWeight.w600)),
      ),
      if (project.products == null || project.products!.isEmpty)
        Text('—', style: AppTheme.appTextStyle(context, color: AppTheme.textSecondary))
      else
        for (final p in project.products!) _projectProductCard(context, p, l10n),
      const SizedBox(height: AppTheme.spaceMd),
      Text(
        'History',
        style: AppTheme.appTextStyle(context, fontWeight: FontWeight.w700, fontSize: 16),
      ),
      const SizedBox(height: AppTheme.spaceSm),
      if (history.isEmpty)
        Text('—', style: AppTheme.appTextStyle(context, color: AppTheme.textSecondary))
      else
        for (var i = 0; i < history.length; i++)
          (() {
            final h = history[i];
            final isCreated = h.action == 'created';
            final cardTitle = isCreated ? 'Created date' : 'Updated date';
            final indexLabel = '${i + 1}. ';
            return Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
              child: AppCard(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$indexLabel$cardTitle',
                      style: AppTheme.appTextStyle(context, fontWeight: FontWeight.w600),
                    ),
                    if (h.at != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          L10nFormatters.formatDateTime(context, h.at!.toLocal()),
                          style: AppTheme.appTextStyle(context, color: AppTheme.textSecondary),
                        ),
                      ),
                    if ((h.byName ?? '').trim().isNotEmpty || (h.byEmail ?? '').trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'By: ${h.byName?.trim().isNotEmpty == true ? h.byName!.trim() : (h.byEmail ?? '—')}',
                          style: AppTheme.appTextStyle(context, color: AppTheme.textSecondary),
                        ),
                      ),
                    const SizedBox(height: 6),
                    if (h.action == 'created') ...[
                      if (project.createdAt != null)
                        Text(
                          'Creation date: ${L10nFormatters.formatDateTime(context, project.createdAt!.toLocal())}',
                          style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary),
                        ),
                      Text(
                        'Project: $name',
                        style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary),
                      ),
                      Text(
                        'Owner: ${owner ?? '—'}',
                        style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary),
                      ),
                      Text(
                        'Description: ${desc ?? '—'}',
                        style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary),
                      ),
                      Text(
                        'Products: ${(project.products ?? const <ProjectProduct>[]).length}',
                        style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary),
                      ),
                    ] else ...[
                      if (project.updatedAt != null)
                        Text(
                          'Last update: ${L10nFormatters.formatDateTime(context, project.updatedAt!.toLocal())}',
                          style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary),
                        ),
                      Text(
                        'Project: $name',
                        style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary),
                      ),
                      Text(
                        'Owner: ${owner ?? '—'}',
                        style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary),
                      ),
                      Text(
                        'Description: ${desc ?? '—'}',
                        style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary),
                      ),
                      Text(
                        'Products: ${(project.products ?? const <ProjectProduct>[]).length}',
                        style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary),
                      ),
                    ],
                  ],
                ),
              ),
            );
          })(),
    ];
    return list;
  }

  List<Widget> _formatItemDetails(BuildContext context, Map<String, dynamic> item) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.reportType == ReportType.projects) {
      return _formatProjectReportDetailWidgets(context, item);
    }
    final list = <Widget>[];
    String labelForKey(String key) {
      final t = key.trim();
      final n = int.tryParse(t);
      if (n != null) return l10n.reportRowItem(n);
      return localizedReportFieldName(context, key);
    }

    void addLine(String key, dynamic val) {
      if (val == null) return;
      String text = val.toString();
      if (val is Map) {
        // Le backend renvoie parfois les dates sous forme de Map (_seconds/_nanoseconds).
        // On formate pour éviter d'afficher '_seconds'/'_nanoseconds' dans l'UI.
        final formattedDate = L10nFormatters.formatDateFromApi(context, val);
        if (formattedDate != null) {
          text = formattedDate;
        } else if (val.containsKey('name')) {
          text = (val['name'] ?? '').toString();
        } else {
          text = val.toString();
        }
      }
      // Normaliser la clé pour matcher même si elle contient ":" ou autres séparateurs (ex: "User::")
      final kn = key
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (kn == 'status' && text.isNotEmpty) {
        text = localizedUiStatus(context, text);
      }
      // Localiser les noms utilisateurs connus (administrator / warehouse user)
      if ((kn == 'validatedby' || kn == 'createdby' || kn == 'user') && text.isNotEmpty) {
        text = localizedDisplayUserName(context, localizedApproverName(context, text));
      }

      // Localiser certaines valeurs de type (distribution / order / return)
      if (kn == 'type' && text.isNotEmpty) {
        final t = text.trim().toLowerCase();
        if (t == 'distribution') text = l10n.distributions;
        if (t == 'order') text = l10n.orders;
        if (t == 'return') text = l10n.returns;
      }
      // Localiser certaines valeurs "reason" / "notes" qui arrivent en anglais depuis l'API
      if (kn == 'reason' && text.isNotEmpty) {
        final r = text.trim().toLowerCase();
        if (r == 'returned as damaged') text = 'أُرجِع كـ تالف';
      }
      if (kn == 'notes' && text.isNotEmpty) {
        final n = text.trim().toLowerCase();
        if (n == 'distribution validated') text = 'تم اعتماد التوزيع';
        if (n == 'damaged product from return') text = 'منتج تالف من مرتجع';
      }

      // Utiliser les libellés localisés "Created by" / "Validated by" en arabe
      if (kn == 'validatedby') {
        list.add(Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
          child: Text(l10n.validatedByLabel(text), style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary)),
        ));
        return;
      }
      if (kn == 'createdby') {
        list.add(Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
          child: Text(l10n.createdByLabel(text), style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary)),
        ));
        return;
      }
      if (kn == 'approvedby') {
        list.add(Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
          child: Text(l10n.approvedByLabel(text), style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary)),
        ));
        return;
      }
      if (kn == 'reportedby') {
        // Pas de clé l10n dédiée: afficher en arabe ici.
        list.add(Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
          child: Text('أبلغ من: $text', style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary)),
        ));
        return;
      }
      list.add(Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
        child: Text('${labelForKey(key)}: $text', style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary)),
      ));
    }

    // Distributions: display Material Request, created date, validated date, distribution date (when distribution happens)
    if (widget.reportType == ReportType.distributions) {
      final materialRequest = item['bonAlimentation'] ?? item['bon_alimentation'];
      if (materialRequest != null && materialRequest.toString().isNotEmpty) {
        list.add(Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
          child: Text('${l10n.materialRequestLabel} $materialRequest', style: AppTheme.appTextStyle(context, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        ));
      }
      final createdStr = L10nFormatters.formatDateFromApi(context, item['createdAt']);
      final validatedStr = L10nFormatters.formatDateFromApi(context, item['validatedAt']);
      final distStr = L10nFormatters.formatDateFromApi(context, item['distributionDate']);
      if (createdStr != null) {
        list.add(Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
          child: Text('${l10n.createdDate} $createdStr', style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary)),
        ));
      }
      if (validatedStr != null) {
        list.add(Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
          child: Text('${l10n.validatedDate} $validatedStr', style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary)),
        ));
      }
      if (distStr != null) {
        list.add(Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
          child: Text('${l10n.distributionDateLabel} $distStr', style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary)),
        ));
      }
    }

    // Orders: display creation date, approved date, distribution date
    if (widget.reportType == ReportType.orders) {
      final createdStr = L10nFormatters.formatDateFromApi(context, item['createdAt']);
      final approvedStr = L10nFormatters.formatDateFromApi(context, item['approvedAt']);
      final distStr = L10nFormatters.formatDateFromApi(context, item['deliveryDate']);
      if (createdStr != null) {
        list.add(Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
          child: Text('${l10n.creationDate} $createdStr', style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary)),
        ));
      }
      if (approvedStr != null) {
        list.add(Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
          child: Text('${l10n.approvedDate} $approvedStr', style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary)),
        ));
      }
      if (distStr != null) {
        list.add(Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
          child: Text('${l10n.distributionDateLabel} $distStr', style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary)),
        ));
      }
    }

    // Stock history: display product creation date
    if (widget.reportType == ReportType.stockHistory) {
      final productCreatedAt = item['productCreatedAt'] ?? item['product']?['createdAt'];
      final formatted = L10nFormatters.formatDateFromApi(context, productCreatedAt);
      if (formatted != null) {
        list.add(Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
          child: Text('${l10n.productCreationDate} $formatted', style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary)),
        ));
      }
    }

    // Returns: display created date, approved date, return date by user
    if (widget.reportType == ReportType.returns) {
      final createdStr = L10nFormatters.formatDateFromApi(context, item['createdAt']);
      final approvedStr = L10nFormatters.formatDateFromApi(context, item['approvedAt']);
      final returnStr = L10nFormatters.formatDateFromApi(context, item['createdAt']);
      if (createdStr != null) {
        list.add(Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
          child: Text('${l10n.createdDate} $createdStr', style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary)),
        ));
      }
      if (approvedStr != null) {
        list.add(Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
          child: Text('${l10n.approvedDate} $approvedStr', style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary)),
        ));
      }
      if (returnStr != null) {
        list.add(Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
          child: Text('${l10n.returnDateByUser} $returnStr', style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary)),
        ));
      }
    }

    // Damaged products: display created date, approved date, report date by user
    if (widget.reportType == ReportType.damagedProducts) {
      final createdStr = L10nFormatters.formatDateFromApi(context, item['createdAt']);
      final approvedStr = L10nFormatters.formatDateFromApi(context, item['approvedAt']);
      final reportStr = L10nFormatters.formatDateFromApi(context, item['createdAt']);
      if (createdStr != null) {
        list.add(Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
          child: Text('${l10n.createdDate} $createdStr', style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary)),
        ));
      }
      if (approvedStr != null) {
        list.add(Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
          child: Text('${l10n.approvedDate} $approvedStr', style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary)),
        ));
      }
      if (reportStr != null) {
        list.add(Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
          child: Text('${l10n.reportDateByUser} $reportStr', style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary)),
        ));
      }
    }

    for (final entry in item.entries) {
      final key = entry.key;
      if (key == 'id' || key == '_id') continue;
      final value = entry.value;
      if (value == null) continue;
      if (widget.reportType == ReportType.stockHistory && key == 'productCreatedAt') continue;
      if (widget.reportType == ReportType.damagedProducts && (key == 'productCreatedAt' || key == 'productUpdatedAt' || key == 'createdAt' || key == 'approvedAt' || key == 'updatedAt')) continue;
      if (widget.reportType == ReportType.returns && (key == 'approvedAt' || key == 'createdAt' || key == 'updatedAt')) continue;
      if (widget.reportType == ReportType.orders && (key == 'createdAt' || key == 'updatedAt' || key == 'approvedAt' || key == 'deliveryDate')) continue;
      if (widget.reportType == ReportType.distributions && (key == 'validatedAt' || key == 'createdAt' || key == 'updatedAt' || key == 'bonAlimentation' || key == 'bon_alimentation' || key == 'distributionDate' || key == 'serialNumber' || key == 'serial_number')) continue;
      if (value is Map) {
        final m = Map<String, dynamic>.from(value);
        final formattedDate = L10nFormatters.formatDateFromApi(context, m);
        if (formattedDate != null) {
          // Afficher la date en 2 lignes (comme les autres champs),
          // au lieu de lister _seconds/_nanoseconds.
          list.add(Padding(
            padding: const EdgeInsets.only(top: AppTheme.spaceSm, bottom: 4),
            child: Text(
              localizedReportFieldName(context, key),
              style: AppTheme.appTextStyle(context, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
          ));
          list.add(Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
            child: Text(
              formattedDate,
              style: AppTheme.appTextStyle(context, color: AppTheme.textPrimary),
            ),
          ));
        } else if (m.containsKey('name')) {
          addLine(key, m['name']);
        } else {
          list.add(Padding(
            padding: const EdgeInsets.only(top: AppTheme.spaceSm, bottom: 4),
            child: Text(localizedReportFieldName(context, key), style: AppTheme.appTextStyle(context, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ));
          for (final e in m.entries) {
            if (e.key == 'id' || e.key == '_id') continue;
            addLine(e.key.toString(), e.value);
          }
        }
      } else if (value is List) {
        list.add(Padding(
          padding: const EdgeInsets.only(top: AppTheme.spaceSm, bottom: 4),
          child: Text(localizedReportFieldName(context, key.toString()), style: AppTheme.appTextStyle(context, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        ));
        for (var i = 0; i < value.length && i < 10; i++) {
          final v = value[i];
          if (v is Map) {
            final prod = v['product'];
            final qty = v['quantity'];
            addLine(
              '  ${i + 1}',
              prod != null
                  ? '${prod['name'] != null && prod['name'].toString().trim().isNotEmpty ? localizedApiProductName(context, prod['name'].toString()) : l10n.product}: $qty'
                  : v.toString(),
            );
          } else {
            addLine('  ${i + 1}', v.toString());
          }
        }
        if (value.length > 10) {
          list.add(Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
            child: Text('  ${l10n.andMore}', style: AppTheme.appTextStyle(context, color: AppTheme.textSecondary)),
          ));
        }
      } else {
        addLine(key, value);
      }
    }
    return list;
  }
}
