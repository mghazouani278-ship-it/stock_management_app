import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/mrp_row.dart';
import '../../../models/store.dart';
import '../../../models/user.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/l10n_formatters.dart';
import '../../../utils/mrp_report_pdf.dart';
import '../../../utils/product_localized.dart';
import '../../../utils/project_localized.dart';
import '../../../utils/store_localized.dart';
import '../../../widgets/connection_error_widget.dart';

class MrpReportScreen extends StatefulWidget {
  const MrpReportScreen({super.key});

  @override
  State<MrpReportScreen> createState() => _MrpReportScreenState();
}

class _MrpReportScreenState extends State<MrpReportScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selectedKeys = {};

  List<MrpRow> _rows = [];
  MrpTotals _totals = MrpTotals();
  List<Project> _projects = [];
  List<Store> _stores = [];

  bool _loading = true;
  String? _error;
  int _page = 1;
  final int _pageSize = 50;
  int _totalCount = 0;
  int _totalPages = 1;
  String? _calculatedAt;

  String _sortBy = 'product';
  String _sortDir = 'asc';
  String? _status;
  String? _warehouseId;
  final Set<String> _projectIds = {};

  @override
  void initState() {
    super.initState();
    // Wait for first frame so InheritedWidgets (l10n) / setState are safe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLookups();
      _load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final results = await Future.wait([
        _api.get('/projects', queryParams: {'light': 'true'}),
        _api.get('/stores'),
      ]);
      if (!mounted) return;
      if (results[0]['success'] == true && results[0]['data'] is List) {
        _projects = (results[0]['data'] as List)
            .map((e) => Project.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      if (results[1]['success'] == true && results[1]['data'] is List) {
        _stores = (results[1]['data'] as List)
            .map((e) => Store.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      setState(() {});
    } catch (_) {}
  }

  Map<String, String> _queryParams() {
    final q = <String, String>{
      'page': '$_page',
      'pageSize': '$_pageSize',
      'sortBy': _sortBy,
      'sortDir': _sortDir,
    };
    final search = _searchCtrl.text.trim();
    if (search.isNotEmpty) q['search'] = search;
    if (_status != null) q['status'] = _status!;
    if (_warehouseId != null) q['warehouseId'] = _warehouseId!;
    if (_projectIds.isNotEmpty) q['projectIds'] = _projectIds.join(',');
    return q;
  }

  String _filtersSummary() {
    final parts = <String>[];
    if (_searchCtrl.text.trim().isNotEmpty) parts.add('search=${_searchCtrl.text.trim()}');
    if (_status != null) parts.add('status=$_status');
    if (_warehouseId != null) parts.add('warehouse=$_warehouseId');
    if (_projectIds.isNotEmpty) parts.add('projects=${_projectIds.length}');
    return parts.join(', ');
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.get('/reports/mrp', queryParams: _queryParams());
      if (!mounted) return;
      if (res['success'] == true && res['data'] is List) {
        setState(() {
          _rows = (res['data'] as List)
              .map((e) => MrpRow.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          _totals = MrpTotals.fromJson(
            res['totals'] is Map ? Map<String, dynamic>.from(res['totals'] as Map) : null,
          );
          _totalCount = (res['count'] as num?)?.toInt() ?? _rows.length;
          _totalPages = (res['totalPages'] as num?)?.toInt() ?? 1;
          _calculatedAt = res['calculatedAt']?.toString();
          _loading = false;
          _selectedKeys.removeWhere((k) => !_rows.any((r) => r.key == k));
        });
      } else {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _loading = false;
          _error = res['message']?.toString() ?? l10n.procurementLoadFailed;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _audit(String action, List<MrpRow> rows) async {
    try {
      await _api.post('/reports/mrp/audit', {
        'action': action,
        'selectedProducts': rows.map((r) => {'key': r.key, 'product': r.product, 'sku': r.sku}).toList(),
        'filters': _queryParams(),
      });
    } catch (_) {}
  }

  String _productLabel(MrpRow r) {
    final ar = r.productNameAr?.trim();
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final name = (isAr && ar != null && ar.isNotEmpty)
        ? ar
        : localizedApiProductName(context, r.product);
    if (r.color != null && r.color!.isNotEmpty) {
      return '$name (${localizedVariantOrColorLabel(context, r.color!)})';
    }
    return name;
  }

  String _requiredPerProjectText(MrpRow r) {
    if (r.requiredPerProject.isEmpty) return '—';
    return r.requiredPerProject.map((p) {
      final n = localizedProjectName(context, p.projectName, nameAr: p.projectNameAr);
      return '$n: ${p.required}';
    }).join('\n');
  }

  Future<void> _showPrintOptions() async {
    final l10n = AppLocalizations.of(context)!;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                l10n.procurementPrintPdf,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.select_all),
              title: Text(l10n.procurementAllProducts),
              subtitle: Text(l10n.procurementCurrentPageCount(_rows.length)),
              onTap: () => Navigator.pop(ctx, 'all'),
            ),
            ListTile(
              leading: const Icon(Icons.checklist),
              title: Text(l10n.procurementSelectedProducts),
              subtitle: Text(
                _selectedKeys.isEmpty
                    ? l10n.procurementSelectRowsFirst
                    : l10n.procurementSelectedCount(_selectedKeys.length),
              ),
              enabled: _selectedKeys.isNotEmpty,
              onTap: _selectedKeys.isEmpty ? null : () => Navigator.pop(ctx, 'selected'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(l10n.procurementByProject),
              subtitle: Text(l10n.procurementChooseOneProject),
              onTap: () => Navigator.pop(ctx, 'project'),
            ),
            ListTile(
              leading: const Icon(Icons.table_view_outlined),
              title: Text(l10n.procurementExportExcel),
              onTap: () => Navigator.pop(ctx, 'excel'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'excel') {
      await _exportExcel();
      return;
    }
    if (choice == 'project') {
      await _printByProject();
      return;
    }
    final rows = choice == 'selected'
        ? _rows.where((r) => _selectedKeys.contains(r.key)).toList()
        : _rows;
    await _printPdf(
      rows,
      mode: choice == 'selected'
          ? ProcurementPrintMode.selectedProducts
          : ProcurementPrintMode.allProducts,
    );
  }

  Future<void> _printByProject() async {
    final l10n = AppLocalizations.of(context)!;
    if (_projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.procurementNoProjects)),
      );
      return;
    }
    final project = await showDialog<Project>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.procurementPrintByProject),
        children: _projects
            .map(
              (p) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, p),
                child: Text(p.displayName(context)),
              ),
            )
            .toList(),
      ),
    );
    if (project == null || !mounted) return;

    List<MrpRow> rows;
    try {
      final q = Map<String, String>.from(_queryParams())
        ..['page'] = '1'
        ..['pageSize'] = '500'
        ..['projectIds'] = project.id;
      final res = await _api.get('/reports/mrp', queryParams: q);
      if (res['success'] == true && res['data'] is List) {
        rows = (res['data'] as List)
            .map((e) => MrpRow.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } else {
        rows = _rows;
      }
    } catch (_) {
      rows = _rows;
    }

    await _printPdf(
      rows,
      mode: ProcurementPrintMode.byProject,
      projectId: project.id,
      projectName: project.displayName(context),
    );
  }

  Future<void> _printPdf(
    List<MrpRow> rows, {
    required ProcurementPrintMode mode,
    String? projectId,
    String? projectName,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.procurementNoRowsToPrint)),
      );
      return;
    }
    final user = context.read<AuthProvider>().user;
    await _audit('print', rows);
    if (!mounted) return;
    await MrpReportPdf.printReport(
      context: context,
      rows: rows,
      printedBy: user?.name ?? user?.email ?? l10n.userFallback,
      filtersSummary: _filtersSummary(),
      mode: mode,
      projectId: projectId,
      projectName: projectName,
    );
  }

  Future<void> _exportExcel() async {
    final l10n = AppLocalizations.of(context)!;
    final rows = _selectedKeys.isEmpty
        ? _rows
        : _rows.where((r) => _selectedKeys.contains(r.key)).toList();
    if (rows.isEmpty) return;
    await _audit('export_excel', rows);
    final buf = StringBuffer();
    buf.writeln(
      [
        l10n.product,
        l10n.procurementColRequiredPerProject,
        l10n.procurementColTotalRequired,
        l10n.procurementColRemaining,
        l10n.procurementColWarehouseStock,
        l10n.procurementColQtyToPurchase,
      ].join(','),
    );
    for (final r in rows) {
      buf.writeln(
        [
          _csv(_productLabel(r)),
          _csv(_requiredPerProjectText(r).replaceAll('\n', ' | ')),
          r.totalRequired,
          r.remainingQuantity,
          r.warehouseStock,
          r.quantityToPurchase,
        ].join(','),
      );
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.procurementExcelCopied),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _csv(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  void _toggleSort(String field) {
    setState(() {
      if (_sortBy == field) {
        _sortDir = _sortDir == 'asc' ? 'desc' : 'asc';
      } else {
        _sortBy = field;
        _sortDir = 'asc';
      }
      _page = 1;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final narrow = MediaQuery.sizeOf(context).width < 700;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(l10n.procurementPlanning),
        actions: [
          IconButton(
            tooltip: l10n.procurementRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
          IconButton(
            tooltip: l10n.procurementPrintPdf,
            icon: const Icon(Icons.print_outlined),
            onPressed: _rows.isEmpty ? null : _showPrintOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(l10n),
          if (_calculatedAt != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '${l10n.procurementLastCalculated(
                    L10nFormatters.formatDateFromApi(context, _calculatedAt) ?? _calculatedAt!,
                    _totalCount,
                  )}'
                  '${_selectedKeys.isNotEmpty ? '  •  ${l10n.procurementSelectedCount(_selectedKeys.length)}' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ),
            ),
          if (narrow)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.procurementSwipeHint,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ),
            ),
          Expanded(child: _buildBody(l10n: l10n, narrow: narrow)),
          _buildTotalsBar(l10n),
          _buildPagination(l10n),
        ],
      ),
    );
  }

  Widget _buildFilters(AppLocalizations l10n) {
    return Material(
      elevation: 1,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  labelText: l10n.procurementSearchHint,
                  prefixIcon: const Icon(Icons.search, size: 18),
                ),
                onSubmitted: (_) {
                  _page = 1;
                  _load();
                },
              ),
            ),
            DropdownButton<String?>(
              value: _status,
              hint: Text(l10n.status),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.procurementAllStatuses)),
                DropdownMenuItem(value: 'in_stock', child: Text(l10n.procurementStatusInStock)),
                DropdownMenuItem(value: 'partial', child: Text(l10n.procurementStatusPartial)),
                DropdownMenuItem(
                  value: 'purchase_required',
                  child: Text(l10n.procurementStatusPurchaseRequired),
                ),
              ],
              onChanged: (v) {
                setState(() {
                  _status = v;
                  _page = 1;
                });
                _load();
              },
            ),
            DropdownButton<String?>(
              value: _warehouseId,
              hint: Text(l10n.warehouse),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.procurementAllWarehouses)),
                ..._stores.map(
                  (s) => DropdownMenuItem(value: s.id, child: Text(s.displayName(context))),
                ),
              ],
              onChanged: (v) {
                setState(() {
                  _warehouseId = v;
                  _page = 1;
                });
                _load();
              },
            ),
            OutlinedButton.icon(
              onPressed: () => _pickProjects(l10n),
              icon: const Icon(Icons.folder_outlined, size: 18),
              label: Text(
                _projectIds.isEmpty
                    ? l10n.procurementAllProjects
                    : l10n.procurementProjectsCount(_projectIds.length),
              ),
            ),
            FilledButton(
              onPressed: () {
                _page = 1;
                _load();
              },
              child: Text(l10n.procurementApply),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProjects(AppLocalizations l10n) async {
    final temp = Set<String>.from(_projectIds);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(l10n.procurementFilterProjects),
          content: SizedBox(
            width: 360,
            height: 360,
            child: ListView(
              children: _projects
                  .map(
                    (p) => CheckboxListTile(
                      value: temp.contains(p.id),
                      title: Text(p.displayName(context)),
                      onChanged: (v) => setLocal(() {
                        if (v == true) {
                          temp.add(p.id);
                        } else {
                          temp.remove(p.id);
                        }
                      }),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            TextButton(
              onPressed: () {
                temp.clear();
                setLocal(() {});
              },
              child: Text(l10n.procurementClear),
            ),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.ok)),
          ],
        ),
      ),
    );
    if (ok == true) {
      setState(() {
        _projectIds
          ..clear()
          ..addAll(temp);
        _page = 1;
      });
      _load();
    }
  }

  Widget _buildBody({required AppLocalizations l10n, required bool narrow}) {
    if (_error != null && _rows.isEmpty && !_loading) {
      return ConnectionErrorWidget(message: _error!, onRetry: _load);
    }
    if (_rows.isEmpty && !_loading) {
      return Center(child: Text(l10n.procurementNoData));
    }
    if (_rows.isEmpty && _loading) {
      // Brief wait only — data usually arrives in ~1s; avoid endless blank spinner.
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(child: narrow ? _buildMobileCards(l10n) : _buildDesktopTable(l10n)),
      ],
    );
  }

  Widget _buildDesktopTable(AppLocalizations l10n) {
    final allSelected = _rows.isNotEmpty && _rows.every((r) => _selectedKeys.contains(r.key));

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth < 900 ? 900 : constraints.maxWidth),
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                  columnSpacing: 20,
                  columns: [
                    DataColumn(
                      label: Checkbox(
                        value: allSelected,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedKeys.addAll(_rows.map((r) => r.key));
                            } else {
                              for (final r in _rows) {
                                _selectedKeys.remove(r.key);
                              }
                            }
                          });
                        },
                      ),
                    ),
                    _sortCol(l10n.product, 'product'),
                    DataColumn(label: Text(l10n.procurementColRequiredPerProject)),
                    _sortCol(l10n.procurementColTotalRequired, 'totalRequired', numeric: true),
                    _sortCol(l10n.procurementColRemaining, 'remainingQuantity', numeric: true),
                    _sortCol(l10n.procurementColWarehouseStock, 'warehouseStock', numeric: true),
                    _sortCol(l10n.procurementColQtyToPurchase, 'quantityToPurchase', numeric: true),
                  ],
                  rows: _rows.map((r) {
                    final selected = _selectedKeys.contains(r.key);
                    return DataRow(
                      selected: selected,
                      cells: [
                        DataCell(
                          Checkbox(
                            value: selected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedKeys.add(r.key);
                                } else {
                                  _selectedKeys.remove(r.key);
                                }
                              });
                            },
                          ),
                        ),
                        DataCell(Text(_productLabel(r))),
                        DataCell(
                          Text(
                            _requiredPerProjectText(r),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        DataCell(Text('${r.totalRequired}')),
                        DataCell(Text('${r.remainingQuantity}')),
                        DataCell(Text('${r.warehouseStock}')),
                        DataCell(
                          Text(
                            '${r.quantityToPurchase}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: r.quantityToPurchase > 0 ? Colors.red.shade700 : Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileCards(AppLocalizations l10n) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: _rows.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildMobileHorizontalTableHint(l10n);
        }
        final r = _rows[index - 1];
        final selected = _selectedKeys.contains(r.key);
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          elevation: 0.5,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() {
                if (selected) {
                  _selectedKeys.remove(r.key);
                } else {
                  _selectedKeys.add(r.key);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: selected,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedKeys.add(r.key);
                            } else {
                              _selectedKeys.remove(r.key);
                            }
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          _productLabel(r),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _kv(l10n.procurementColRequiredPerProject, _requiredPerProjectText(r)),
                  _kv(l10n.procurementColTotalRequired, '${r.totalRequired}'),
                  _kv(l10n.procurementColRemaining, '${r.remainingQuantity}'),
                  _kv(l10n.procurementColWarehouseStock, '${r.warehouseStock}'),
                  _kv(
                    l10n.procurementColQtyToPurchase,
                    '${r.quantityToPurchase}',
                    valueColor: r.quantityToPurchase > 0 ? Colors.red.shade700 : Colors.green.shade700,
                    boldValue: true,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileHorizontalTableHint(AppLocalizations l10n) {
    return ExpansionTile(
      initiallyExpanded: false,
      tilePadding: EdgeInsets.zero,
      title: Text(
        l10n.procurementFullTable,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      children: [
        SizedBox(
          height: 220,
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                  columnSpacing: 16,
                  dataRowMinHeight: 40,
                  dataRowMaxHeight: 72,
                  columns: [
                    DataColumn(label: Text(l10n.product)),
                    DataColumn(label: Text(l10n.procurementColRequiredPerProject)),
                    DataColumn(label: Text(l10n.procurementColTotalRequiredShort), numeric: true),
                    DataColumn(label: Text(l10n.procurementColRemainingShort), numeric: true),
                    DataColumn(label: Text(l10n.procurementColWhStockShort), numeric: true),
                    DataColumn(label: Text(l10n.procurementColToPurchaseShort), numeric: true),
                  ],
                  rows: _rows
                      .map(
                        (r) => DataRow(
                          cells: [
                            DataCell(SizedBox(width: 140, child: Text(_productLabel(r), maxLines: 2))),
                            DataCell(
                              SizedBox(
                                width: 160,
                                child: Text(
                                  _requiredPerProjectText(r),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                            DataCell(Text('${r.totalRequired}')),
                            DataCell(Text('${r.remainingQuantity}')),
                            DataCell(Text('${r.warehouseStock}')),
                            DataCell(Text('${r.quantityToPurchase}')),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _kv(String label, String value, {Color? valueColor, bool boldValue = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor,
                fontWeight: boldValue ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataColumn _sortCol(String label, String field, {bool numeric = false}) {
    final active = _sortBy == field;
    return DataColumn(
      numeric: numeric,
      label: InkWell(
        onTap: () => _toggleSort(field),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (active)
              Icon(
                _sortDir == 'asc' ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalsBar(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          _tot(l10n.procurementTotalsProducts, '${_totals.totalProducts}'),
          _tot(l10n.procurementTotalsTotalRequired, '${_totals.totalRequired}'),
          _tot(l10n.procurementTotalsRemaining, '${_totals.totalRemaining}'),
          _tot(l10n.procurementTotalsWarehouseStock, '${_totals.totalWarehouseStock}'),
          _tot(l10n.procurementTotalsToPurchase, '${_totals.totalQuantityToPurchase}'),
        ],
      ),
    );
  }

  Widget _tot(String label, String value) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          TextSpan(text: value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPagination(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Text(l10n.procurementPageOf(_page, _totalPages)),
          const Spacer(),
          IconButton(
            onPressed: _page > 1 && !_loading
                ? () {
                    setState(() => _page -= 1);
                    _load();
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            onPressed: _page < _totalPages && !_loading
                ? () {
                    setState(() => _page += 1);
                    _load();
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
