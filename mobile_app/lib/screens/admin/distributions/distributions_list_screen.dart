import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/distribution.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_search_bar.dart';
import '../../../widgets/connection_error_widget.dart';
import '../../../utils/embedded_ref_localized.dart';
import '../../../utils/l10n_ui_helpers.dart';
import '../../../utils/product_localized.dart';
import '../../warehouse/warehouse_distribution_form_screen.dart';

class DistributionsListScreen extends StatefulWidget {
  final bool hideValidate;
  final bool showCreateFab;
  /// When true (warehouse view): show only Validate button, hide Refuse. When false (admin): show both.
  final bool warehouseValidateOnly;
  /// When false (warehouse): hide Delete button. When true (admin): show Delete.
  final bool allowDelete;

  const DistributionsListScreen({super.key, this.hideValidate = false, this.showCreateFab = false, this.warehouseValidateOnly = false, this.allowDelete = true});

  @override
  State<DistributionsListScreen> createState() => _DistributionsListScreenState();
}

class _DistributionsListScreenState extends State<DistributionsListScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<Distribution> _distributions = [];
  List<Map<String, dynamic>> _statusNotifications = [];
  bool _loading = true;
  bool _loadingNotifications = true;
  String? _error;
  bool _showSearch = false;
  String? _newestAdminDistributionId;
  bool _newestAdminHighlightConsumed = false;

  bool _isSuccessStatus(String status) {
    final s = status.toLowerCase().trim();
    return s == 'validated' || s == 'accepted' || s == 'completed';
  }

  bool _isErrorStatus(String status) {
    final s = status.toLowerCase().trim();
    return s == 'refused' || s == 'rejected' || s == 'cancelled';
  }

  void _consumeNewestHighlightIfMatch(Distribution dist) {
    if (widget.hideValidate || _newestAdminHighlightConsumed) return;
    if (_newestAdminDistributionId == null) return;
    if (_newestAdminDistributionId != dist.id) return;
    if (!mounted) return;
    setState(() => _newestAdminHighlightConsumed = true);
  }

  @override
  void initState() {
    super.initState();
    _loadDistributions();
    if (widget.hideValidate) {
      _loadStatusNotifications();
      _markNotificationsRead();
    }
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Distribution> get _filteredDistributions {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _distributions;
    return _distributions.where((d) =>
        d.bonAlimentation.toLowerCase().contains(q) ||
        (d.project?.name.toLowerCase().contains(q) ?? false) ||
        (d.project?.nameAr?.toLowerCase().contains(q) ?? false) ||
        (d.store?.name.toLowerCase().contains(q) ?? false) ||
        (d.store?.nameAr?.toLowerCase().contains(q) ?? false) ||
        d.status.toLowerCase().contains(q)).toList();
  }

  Future<void> _loadDistributions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _apiService.get('/distributions');
      if (!mounted) return;
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _distributions = (res['data'] as List)
              .map((e) => Distribution.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          if (!widget.hideValidate && !_newestAdminHighlightConsumed && _distributions.isNotEmpty) {
            _newestAdminDistributionId ??= _distributions.first.id;
          }
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _loadStatusNotifications() async {
    if (!widget.hideValidate) return;
    setState(() => _loadingNotifications = true);
    try {
      final res = await _apiService.get('/distribution-notifications/warehouse');
      if (!mounted) return;
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _statusNotifications = (res['data'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _loadingNotifications = false;
        });
      } else {
        setState(() => _loadingNotifications = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingNotifications = false);
    }
  }

  Future<void> _markNotificationsRead() async {
    if (!widget.hideValidate) return;
    try {
      await _apiService.put('/distribution-notifications/warehouse/read', {});
      if (mounted) _loadStatusNotifications();
    } catch (_) {}
  }

  Future<void> _deleteDistribution(Distribution dist) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteDistribution),
        content: Text(l10n.confirmDeleteDistribution(dist.bonAlimentation)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: Text(l10n.delete)),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _apiService.delete('/distributions/${dist.id}');
      if (mounted) _loadDistributions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBarError(e.toString().replaceAll('Exception: ', '')),
        );
      }
    }
  }

  Future<void> _refuseDistribution(Distribution dist) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.refuseDistribution),
        content: Text(l10n.refuseDistributionQuestion(dist.bonAlimentation)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: Text(l10n.refuse)),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _apiService.put('/distributions/${dist.id}/refuse', {});
      if (mounted) _loadDistributions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBarError(e.toString().replaceAll('Exception: ', '')),
        );
      }
    }
  }

  Future<void> _validateDistribution(Distribution dist) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.validateDistribution),
        content: Text(l10n.validateDistributionQuestion(dist.bonAlimentation)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.validate)),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _apiService.put('/distributions/${dist.id}/validate', {});
      if (mounted) _loadDistributions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBarError(e.toString().replaceAll('Exception: ', '')),
        );
      }
    }
  }

  void _showDetails(Distribution dist) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (dist.status == 'pending' && !widget.hideValidate)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _validateDistribution(dist);
                          },
                          child: Text(widget.warehouseValidateOnly ? l10n.validate : l10n.approve),
                        ),
                      ),
                      if (!widget.warehouseValidateOnly) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _refuseDistribution(dist);
                            },
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                            child: Text(l10n.refuse),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              Text(
                '${l10n.materialRequestLabel} ${dist.bonAlimentation}',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (dist.project != null)
                Text(l10n.projectLabel(dist.project!.displayName(context))),
              if (dist.store != null)
                Text('${l10n.store}: ${dist.store!.displayName(context)}'),
              if (dist.distributionDate != null && dist.distributionDate!.isNotEmpty)
                Text(l10n.distributionDateValue(dist.distributionDate!)),
              Text(
                l10n.statusWithValue(localizedUiStatus(ctx, dist.status)),
                style: TextStyle(
                  color: _isSuccessStatus(dist.status)
                      ? Colors.green
                      : _isErrorStatus(dist.status)
                          ? Colors.red
                          : const Color(0xFFC62828),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.productsLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              ...dist.products.map((p) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '  • ${p.productName != null && p.productName!.trim().isNotEmpty ? localizedApiProductName(ctx, p.productName!) : l10n.product}: ${p.quantity}',
                    ),
                  )),
              if (dist.notes != null && dist.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.notesLabel(dist.notes!)),
              ],
              if (dist.createdBy != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    l10n.createdByLabel(localizedDisplayUserName(ctx, dist.createdBy!.name, nameAr: dist.createdBy!.nameAr)),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              if (dist.validatedBy != null)
                Text(
                  l10n.validatedByLabel(localizedDisplayUserName(ctx, dist.validatedBy!.name, nameAr: dist.validatedBy!.nameAr)),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppSearchBar(
          title: AppLocalizations.of(context)!.distributions,
          searchHint: AppLocalizations.of(context)!.searchDistributionsHint,
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
            onPressed: _loading
                ? null
                : () async {
                    await _loadDistributions();
                    if (widget.hideValidate) await _loadStatusNotifications();
                  },
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: widget.showCreateFab
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WarehouseDistributionFormScreen()),
                );
                if (result == true && mounted) _loadDistributions();
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading && _distributions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _distributions.isEmpty) {
      return ConnectionErrorWidget(message: _error!, onRetry: _loadDistributions);
    }
    if (_distributions.isEmpty && (!widget.hideValidate || _statusNotifications.isEmpty)) {
      return RefreshIndicator(
        onRefresh: () async {
          await _loadDistributions();
          if (widget.hideValidate) await _loadStatusNotifications();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: Center(
              child: Text(
                AppLocalizations.of(context)!.noDistributionsCreateHint,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }
    final items = _filteredDistributions;
    return RefreshIndicator(
      onRefresh: () async {
        await _loadDistributions();
        if (widget.hideValidate) await _loadStatusNotifications();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.hideValidate && _statusNotifications.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.notifications,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._statusNotifications.map((n) {
                    final status = n['status'] as String? ?? '';
                    final isAccepted = status == 'accepted';
                    final bon = n['bonAlimentation'] ?? n['distributionId'] ?? '—';
                    final projectName = n['projectName'] ?? '';
                    final storeName = n['storeName'] ?? '';
                    final subtitle = [projectName, storeName].where((s) => s.isNotEmpty).join(' • ');
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isAccepted
                          ? Colors.green.withOpacity(0.08)
                          : Colors.red.withOpacity(0.08),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isAccepted ? Colors.green : Colors.red,
                          child: Icon(
                            isAccepted ? Icons.check : Icons.close,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          isAccepted
                              ? AppLocalizations.of(context)!.distributionAccepted(bon)
                              : AppLocalizations.of(context)!.distributionRefused(bon),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: Text(
                  _searchController.text.trim().isEmpty
                      ? AppLocalizations.of(context)!.noDistributions
                      : AppLocalizations.of(context)!.noDistributionsMatch,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...items.asMap().entries.map((entry) {
              final dist = entry.value;
              // Admin screen: highlight newest row until first admin click on it.
              final isNewestAdminItem = !widget.hideValidate &&
                  !_newestAdminHighlightConsumed &&
                  _newestAdminDistributionId == dist.id;
              final isPendingLike = !_isSuccessStatus(dist.status) && !_isErrorStatus(dist.status);
              final forceRed = isNewestAdminItem;
              return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: (isPendingLike || forceRed)
                  ? const Color(0xFFFFEBEE)
                  : null,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: forceRed
                      ? Colors.red
                      : _isSuccessStatus(dist.status)
                      ? Colors.green
                      : _isErrorStatus(dist.status)
                          ? Colors.red
                          : const Color(0xFFC62828),
                  child: Icon(
                    forceRed
                        ? Icons.fiber_new
                        : _isSuccessStatus(dist.status)
                        ? Icons.check
                        : _isErrorStatus(dist.status)
                            ? Icons.close
                            : Icons.pending,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  dist.bonAlimentation,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dist.project != null)
                      Text(dist.project!.displayName(context)),
                    if (dist.store != null)
                      Text(
                        dist.store!.displayName(context),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    Text(
                      localizedUiStatus(context, dist.status),
                      style: TextStyle(
                        fontSize: 12,
                        color: (isPendingLike || forceRed)
                            ? const Color(0xFFC62828)
                            : Colors.grey[600],
                        fontWeight: (isPendingLike || forceRed)
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) async {
                    _consumeNewestHighlightIfMatch(dist);
                    if (value == 'view') {
                      _showDetails(dist);
                    } else if (value == 'delete') {
                      await _deleteDistribution(dist);
                    }
                  },
                  itemBuilder: (context) {
                    final l10n = AppLocalizations.of(context)!;
                    return [
                      PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            const Icon(Icons.visibility),
                            const SizedBox(width: 8),
                            Text(l10n.viewDetails),
                          ],
                        ),
                      ),
                      if (widget.allowDelete)
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline, color: Colors.red),
                              const SizedBox(width: 8),
                              Text(l10n.delete, style: const TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                    ];
                  },
                ),
                onTap: () {
                  _consumeNewestHighlightIfMatch(dist);
                  _showDetails(dist);
                },
              ),
            );
            }),
        ],
      ),
    );
  }
}
