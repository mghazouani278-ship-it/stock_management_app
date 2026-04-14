import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/product_localized.dart';
import '../../../utils/project_localized.dart';
import '../../../utils/store_localized.dart';
import '../../../utils/l10n_formatters.dart';
import '../../../models/store.dart';
import '../../../models/user.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/connection_error_widget.dart';
import 'warehouse_approved_orders_screen.dart';

class WarehouseDistributionFormScreen extends StatefulWidget {
  const WarehouseDistributionFormScreen({super.key});

  @override
  State<WarehouseDistributionFormScreen> createState() => _WarehouseDistributionFormScreenState();
}

class _WarehouseDistributionFormScreenState extends State<WarehouseDistributionFormScreen> {
  final ApiService _apiService = ApiService();
  List<Project> _projects = [];
  List<Store> _stores = [];
  List<Store> _depots = [];
  final _serialNumberController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedProjectId;
  String? _selectedStoreId;
  DateTime _distributionDate = DateTime.now();
  final List<Map<String, dynamic>> _selectedProducts = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _serialNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<Store> get _locations {
    final combined = <Store>[];
    for (final s in _stores) combined.add(s);
    for (final d in _depots) combined.add(d);
    return combined;
  }

  /// Products requested by users for the selected project (requestedQuantity > 0).
  List<Map<String, dynamic>> get _projectProducts {
    if (_selectedProjectId == null) return [];
    final project = _projects.cast<Project?>().firstWhere(
          (p) => p?.id == _selectedProjectId,
          orElse: () => null,
        );
    if (project == null || project.products == null) return [];
    return project.products!
        .where((pp) => pp.requestedQuantity > 0)
        .map((pp) {
          final base = pp.productName ?? pp.product;
          final baseAr = localizedApiProductName(context, base);
          final name = pp.color != null && pp.color!.isNotEmpty
              ? '$baseAr (${localizedVariantOrColorLabel(context, pp.color!)})'
              : baseAr;
          return {
            'productId': pp.product,
            'name': name,
            'color': pp.color,
            'maxQuantity': pp.requestedQuantity,
          };
        })
        .toList();
  }

  int _parseQuantity(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Run all 3 API calls in parallel. Use light projects for faster load (id, name, products only).
      final results = await Future.wait([
        _apiService.get('/projects', queryParams: {'light': '1'}),
        _apiService.get('/stores'),
        _apiService.get('/depots').catchError((_) => <String, dynamic>{}),
      ]);
      final projectsRes = results[0];
      final storesRes = results[1];
      final depotsRes = results[2];
      if (projectsRes['success'] == true && projectsRes['data'] != null) {
        _projects = (projectsRes['data'] as List)
            .map((e) => Project.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (storesRes['success'] == true && storesRes['data'] != null) {
        _stores = (storesRes['data'] as List)
            .map((e) => Store.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (depotsRes['success'] == true && depotsRes['data'] != null) {
        _depots = (depotsRes['data'] as List)
            .map((e) => Store.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _addProduct() {
    final l10n = AppLocalizations.of(context)!;
    final available = _projectProducts;
    if (_selectedProjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBarError(l10n.selectProjectFirst));
      return;
    }
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBarError(l10n.noProductsRequested));
      return;
    }
    int selectedIndex = 0;
    int maxQty = available.isNotEmpty ? _parseQuantity(available[0]['maxQuantity']) : 0;
    final qtyController = TextEditingController(text: '0');
    showDialog(
      context: context,
      builder: (ctx) {
        final dl10n = AppLocalizations.of(ctx)!;
        return StatefulBuilder(
        builder: (ctx, setDialogState) {
          maxQty = _parseQuantity(available[selectedIndex]['maxQuantity']);
          return AlertDialog(
            title: Text(dl10n.addProduct),
            content: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<int>(
                      value: selectedIndex,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: dl10n.product, border: const OutlineInputBorder()),
                      selectedItemBuilder: (ctx) => available.asMap().entries.map((e) {
                        final mq = '${_parseQuantity(e.value['maxQuantity'])}';
                        return Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          dl10n.productNameWithMaxQty(e.value['name']?.toString() ?? '', mq),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          softWrap: false,
                        ),
                      );
                      }).toList(),
                      items: available.asMap().entries.map((e) {
                        final mq = '${_parseQuantity(e.value['maxQuantity'])}';
                        return DropdownMenuItem(
                        value: e.key,
                        child: Text(
                          dl10n.productNameWithMaxQty(e.value['name']?.toString() ?? '', mq),
                          softWrap: true,
                          maxLines: null,
                          overflow: TextOverflow.clip,
                        ),
                      );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() {
                            selectedIndex = v;
                            qtyController.text = '0';
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: dl10n.quantity,
                        hintText: dl10n.maxQtyHintNumber('$maxQty'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(dl10n.cancel)),
              FilledButton(
                onPressed: () {
                  final quantity = int.tryParse(qtyController.text) ?? 0;
                  if (quantity <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBarError(dl10n.pleaseEnterQuantity));
                    return;
                  }
                  if (selectedIndex >= 0 && selectedIndex < available.length) {
                    final p = available[selectedIndex];
                    Navigator.pop(ctx);
                    setState(() {
                      _selectedProducts.add({
                        'productId': p['productId'],
                        'name': p['name'],
                        'quantity': quantity,
                        'color': p['color'],
                      });
                    });
                  }
                },
                child: Text(dl10n.add),
              ),
            ],
          );
        },
      );
      },
    );
  }

  void _removeProduct(int index) {
    setState(() => _selectedProducts.removeAt(index));
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedProjectId == null || _selectedStoreId == null || _selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBarError(l10n.pleaseSelectProjectStore));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final products = _selectedProducts.map((p) {
        final map = <String, dynamic>{
          'product': {'id': p['productId']},
          'quantity': p['quantity'] as int,
        };
        final color = p['color'] as String?;
        if (color != null && color.toString().trim().isNotEmpty) {
          map['color'] = color.toString().trim().toLowerCase();
        }
        return map;
      }).toList();
      final payload = <String, dynamic>{
        'bonAlimentation': _serialNumberController.text.trim().isEmpty ? null : _serialNumberController.text.trim(),
        'project': _selectedProjectId,
        'distributionDate': _distributionDate.toIso8601String().split('T')[0],
        'products': products,
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      };
      if (_depots.any((d) => d.id == _selectedStoreId)) {
        payload['depot'] = _selectedStoreId;
      } else {
        payload['store'] = _selectedStoreId;
      }
      final res = await _apiService.post('/distributions', payload);
      if (mounted) {
        final materialRequest = res['data']?['bonAlimentation'] ?? res['data']?['bon_alimentation'] ?? 'N/A';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.distributionCreated(materialRequest)),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _saving = false;
          _selectedProducts.clear();
          _notesController.clear();
        });
        Navigator.of(context).pop(true);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WarehouseApprovedOrdersScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.createDistribution)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _projects.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.createDistribution)),
        body: ConnectionErrorWidget(message: _error!, onRetry: _loadData),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createDistribution),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _serialNumberController,
              decoration: InputDecoration(
                labelText: l10n.materialRequestOptional,
                hintText: l10n.materialRequestHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _distributionDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _distributionDate = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: '${l10n.distributionDate} *',
                  border: const OutlineInputBorder(),
                ),
child: Text(
                  L10nFormatters.formatDateShort(context, _distributionDate),
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedProjectId,
              isExpanded: true,
              decoration: InputDecoration(labelText: '${l10n.project} *', border: const OutlineInputBorder()),
              items: _projects.map((p) => DropdownMenuItem(
                value: p.id,
                child: Text(p.displayName(context), softWrap: true, maxLines: null, overflow: TextOverflow.clip),
              )).toList(),
              onChanged: (v) => setState(() {
                _selectedProjectId = v;
                _selectedProducts.clear();
              }),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedStoreId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: '${l10n.sourceStoreDepot} *',
                hintText: l10n.selectLocationHint,
                border: const OutlineInputBorder(),
              ),
              items: _locations.map((s) => DropdownMenuItem(
                value: s.id,
                child: Text(s.displayName(context), softWrap: true, maxLines: null, overflow: TextOverflow.clip),
              )).toList(),
              onChanged: (v) => setState(() => _selectedStoreId = v),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.productsRequiredLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                TextButton.icon(
                  onPressed: _projectProducts.isNotEmpty ? _addProduct : null,
                  icon: const Icon(Icons.add),
                  label: Text(_selectedProjectId == null
                      ? l10n.selectProjectFirstShort
                      : _projectProducts.isEmpty
                          ? l10n.noProductsRequestedShort
                          : l10n.add),
                ),
              ],
            ),
            if (_selectedProducts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.noProductsAdded, style: const TextStyle(color: Colors.grey)),
              )
            else
              ..._selectedProducts.asMap().entries.map((e) => ListTile(
                title: Text(
                  e.value['name'] ?? '',
                  softWrap: true,
                  maxLines: null,
                  overflow: TextOverflow.clip,
                ),
                subtitle: Text(
                  l10n.qtyWithOptionalColor(
                    '${e.value['quantity']}',
                    (e.value['color'] as String?) != null ? ' • ${e.value['color']}' : '',
                  ),
                  softWrap: true,
                  maxLines: null,
                  overflow: TextOverflow.clip,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  onPressed: () => _removeProduct(e.key),
                ),
              )),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: l10n.notesOptional,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Material(
                  color: AppTheme.error,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_error!, style: const TextStyle(color: Colors.white))),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.createDistribution),
            ),
          ],
        ),
      ),
    );
  }
}
