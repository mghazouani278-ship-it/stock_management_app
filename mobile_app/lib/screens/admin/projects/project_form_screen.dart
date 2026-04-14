import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../l10n/app_localizations.dart';
import '../../../models/product.dart';
import '../../../models/user.dart' show Project;
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/l10n_formatters.dart';
import '../../../utils/product_localized.dart';

DateTime? _parseLocalYmd(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final t = s.trim();
  final parts = t.split('-');
  if (parts.length == 3) {
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y != null && m != null && d != null) return DateTime(y, m, d);
  }
  return DateTime.tryParse(t);
}

class ProjectFormScreen extends StatefulWidget {
  final Project? project;

  const ProjectFormScreen({super.key, this.project});

  @override
  State<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<ProjectFormScreen> {
  static final DateFormat _boqApiDateFormat = DateFormat('yyyy-MM-dd');

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nameArController = TextEditingController();
  final _projectOwnerController = TextEditingController();
  final _projectOwnerArController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _apiService = ApiService();

  /// Date de création du B.O.Q au niveau projet (sélecteur calendrier).
  DateTime _boqCreationDate = DateTime.now();

  String _status = 'active';
  bool _loading = false;
  String? _error;
  List<Product> _allProducts = [];
  final List<Map<String, dynamic>> _selectedProducts = [];

  /// En édition : dernier projet chargé (liste puis détail GET `/projects/:id`).
  Project? _detailProjectEdit;

  bool get _isEdit => widget.project != null;

  void _applyProjectToForm(Project p) {
    _nameController.text = p.name;
    _nameArController.text = p.nameAr ?? '';
    _projectOwnerController.text = p.projectOwner ?? '';
    _projectOwnerArController.text = p.projectOwnerAr ?? '';
    _descriptionController.text = p.description ?? '';
    _status = p.status.isNotEmpty ? p.status : 'active';
    _boqCreationDate = _parseLocalYmd(p.boqCreationDate) ?? DateTime.now();
    _selectedProducts.clear();
    // Toutes les lignes (y compris quantité 0) pour ne rien « supprimer » du formulaire.
    for (final pp in p.products ?? []) {
      _selectedProducts.add({
        'productId': pp.product,
        'name': pp.productName ?? pp.product,
        'quantity': pp.allowedQuantity,
        'color': pp.color,
        'boqDate': pp.boqDate,
        'manufacturer': null,
      });
    }
  }

  Future<void> _reloadProjectDetail() async {
    final id = widget.project?.id;
    if (id == null || id.isEmpty) return;
    try {
      final res = await _apiService.get('/projects/$id');
      if (!mounted) return;
      if (res['success'] == true && res['data'] != null) {
        final full = Project.fromJson(Map<String, dynamic>.from(res['data']));
        setState(() {
          _detailProjectEdit = full;
          _applyProjectToForm(full);
          _hydrateSelectedManufacturers();
        });
      }
    } catch (_) {
      // Garde les valeurs préremplies depuis la liste.
    }
  }

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _detailProjectEdit = widget.project;
      _applyProjectToForm(widget.project!);
      _reloadProjectDetail();
    }
    _loadProducts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameArController.dispose();
    _projectOwnerController.dispose();
    _projectOwnerArController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getProjectProductsPayload() {
    return _selectedProducts.map((p) {
      final map = {'product': p['productId'], 'allowedQuantity': p['quantity'] as int};
      final color = p['color'] as String?;
      if (color != null && color.isNotEmpty) map['color'] = color;
      final boq = p['boqDate'] as String?;
      if (boq != null && boq.trim().isNotEmpty) map['boqDate'] = boq.trim();
      return map;
    }).toList();
  }

  Future<void> _loadProducts() async {
    try {
      final res = await _apiService.get('/products');
      if (res['success'] == true && res['data'] != null) {
        final products = (res['data'] as List)
            .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
            .where((p) => p.status == 'active')
            .toList();
        setState(() {
          _allProducts = products;
          _hydrateSelectedManufacturers();
        });
      }
    } catch (_) {}
  }

  void _hydrateSelectedManufacturers() {
    for (final row in _selectedProducts) {
      final id = row['productId'] as String?;
      if (id == null) continue;
      try {
        final pr = _allProducts.firstWhere((p) => p.id == id);
        row['manufacturer'] = pr.manufacturer;
      } catch (_) {}
    }
  }

  bool _isProductVariantSelected(String productId, String? color) {
    return _selectedProducts.any((sp) {
      final spId = sp['productId'] as String?;
      final spColor = sp['color'] as String?;
      return spId == productId && spColor == color;
    });
  }

  void _addProduct() {
    if (_allProducts.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    final available = _allProducts.where((p) {
      if (p.availableColors.isEmpty) return !_isProductVariantSelected(p.id, null);
      return p.availableColors.any((c) => !_isProductVariantSelected(p.id, c));
    }).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.allProductsAlreadyAdded)),
      );
      return;
    }
    String? productId = available.first.id;
    final qtyController = TextEditingController(text: '0');
    final variantControllers = <String, TextEditingController>{};
    void disposeVariantControllers() {
      for (final c in variantControllers.values) {
        c.dispose();
      }
      variantControllers.clear();
    }
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final product = _allProducts.firstWhere((p) => p.id == productId, orElse: () => available.first);
          final hasVariants = product.availableColors.isNotEmpty;
          final availableVariants = hasVariants
              ? product.availableColors.where((c) => !_isProductVariantSelected(product.id, c)).toList()
              : <String>[];
          for (final v in availableVariants) {
            variantControllers.putIfAbsent(v, () => TextEditingController(text: '0'));
          }
          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.addProduct),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SearchableProductSelect(
                    label: l10n.product,
                    products: available,
                    value: productId,
                    displayText: (p) => '${p.displayName(ctx)} (${p.displayUnit(ctx)})',
                    onChanged: (v) => setDialogState(() => productId = v),
                  ),
                  const SizedBox(height: 16),
                  if (!hasVariants || availableVariants.isEmpty) ...[
                    TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.maxQuantityUsersCanOrder,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ] else ...[
                    Text(l10n.variantsLabel(product.displayUnit(context)), style: AppTheme.appTextStyle(context, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...availableVariants.map((v) {
                      final ctrl = variantControllers[v] ?? TextEditingController(text: '0');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                localizedVariantOrColorLabel(ctx, v),
                                style: AppTheme.appTextStyle(context, color: AppTheme.textSecondary),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: ctrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: l10n.qtyLabel,
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
              FilledButton(
                onPressed: () {
                  final pid = productId;
                  if (pid == null) return;
                  final prod = _allProducts.firstWhere((p) => p.id == pid);
                  final toAdd = <Map<String, dynamic>>[];
                  if (prod.availableColors.isEmpty) {
                    final q = int.tryParse(qtyController.text) ?? 0;
                    if (q > 0 && !_isProductVariantSelected(pid, null)) {
                      toAdd.add({
                        'productId': pid,
                        'name': prod.name,
                        'quantity': q,
                        'color': null,
                        'boqDate': null,
                        'manufacturer': prod.manufacturer,
                      });
                    }
                  } else {
                    for (final v in availableVariants) {
                      final ctrl = variantControllers[v];
                      final q = int.tryParse(ctrl?.text ?? '0') ?? 0;
                      if (q > 0 && !_isProductVariantSelected(pid, v)) {
                        toAdd.add({
                          'productId': pid,
                          'name': '${prod.name} ($v)',
                          'quantity': q,
                          'color': v,
                          'boqDate': null,
                          'manufacturer': prod.manufacturer,
                        });
                      }
                    }
                  }
                  if (toAdd.isNotEmpty) {
                    disposeVariantControllers();
                    Navigator.pop(ctx);
                    setState(() => _selectedProducts.addAll(toAdd));
                  }
                },
                child: Text(l10n.add),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      qtyController.dispose();
      disposeVariantControllers();
    });
  }

  void _removeProduct(int index) {
    setState(() => _selectedProducts.removeAt(index));
  }

  void _editProductQuantity(int index) {
    final item = _selectedProducts[index];
    final qtyController = TextEditingController(text: (item['quantity'] as int).toString());
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editItem(localizedApiProductName(context, item['name']?.toString() ?? ''))),
        content: TextField(
          controller: qtyController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.maxQty,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () {
              final quantity = int.tryParse(qtyController.text) ?? 0;
              Navigator.pop(ctx);
              if (quantity > 0) {
                setState(() => _selectedProducts[index]['quantity'] = quantity);
              } else {
                setState(() => _selectedProducts.removeAt(index));
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  int _availableStockForProduct(String productId) {
    try {
      final p = _allProducts.firstWhere((x) => x.id == productId);
      final stores = p.stores;
      if (stores == null || stores.isEmpty) return 0;
      return stores.fold<int>(0, (sum, s) => sum + s.quantity);
    } catch (_) {
      return 0;
    }
  }

  bool get _isArabicUi => Localizations.localeOf(context).languageCode.toLowerCase().startsWith('ar');

  String? _buildInsufficientStockMessage() {
    final issues = <String>[];
    final isAr = _isArabicUi;
    for (final row in _selectedProducts) {
      final productId = row['productId'] as String?;
      if (productId == null || productId.isEmpty) continue;
      final requested = (row['quantity'] as int?) ?? 0;
      if (requested <= 0) continue;
      final available = _availableStockForProduct(productId);
      if (requested > available) {
        final missing = requested - available;
        final rawName = row['name']?.toString() ?? '';
        final displayName = localizedApiProductName(context, rawName);
        issues.add(
          isAr
              ? '- $displayName: مطلوب $requested، المخزون $available، النقص $missing'
              : '- $displayName: requested $requested, stock $available, missing $missing',
        );
      }
    }
    if (issues.isEmpty) return null;
    return isAr
        ? 'المخزون غير كافٍ لبعض المنتجات:\n${issues.join('\n')}'
        : 'Insufficient stock for some products:\n${issues.join('\n')}';
  }

  Future<void> _showStockWarningDialog(String message) async {
    if (!mounted) return;
    final isAr = _isArabicUi;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'تنبيه' : 'Warning'),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isAr ? 'حسناً' : 'OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final stockWarning = _buildInsufficientStockMessage();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final productsPayload = _getProjectProductsPayload();
      final data = {
        'name': _nameController.text.trim(),
        'nameAr': _nameArController.text.trim().isEmpty ? null : _nameArController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'boqCreationDate': _boqApiDateFormat.format(_boqCreationDate),
        'products': productsPayload,
        'projectOwner': _projectOwnerController.text.trim().isEmpty ? null : _projectOwnerController.text.trim(),
        'projectOwnerAr': _projectOwnerArController.text.trim().isEmpty ? null : _projectOwnerArController.text.trim(),
        if (_isEdit) 'status': _status,
      };
      if (_isEdit) {
        final res = await _apiService.put('/projects/${widget.project!.id}', data);
        if (res['success'] == true && context.mounted) {
          if (stockWarning != null) {
            await _showStockWarningDialog(stockWarning);
            if (!context.mounted) return;
          }
          Navigator.pop(context, {'reload': true, 'projectPdf': res['data']});
        } else {
          setState(() => _loading = false);
        }
      } else {
        final res = await _apiService.post('/projects', data);
        if (res['success'] == true && context.mounted) {
          if (stockWarning != null) {
            await _showStockWarningDialog(stockWarning);
            if (!context.mounted) return;
          }
          Navigator.pop(context, {'reload': true, 'projectPdf': res['data']});
        } else {
          setState(() => _loading = false);
        }
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
    final projectForMeta = _detailProjectEdit ?? widget.project;
    final updatedAt = projectForMeta?.updatedAt;
    final lastEditStr = updatedAt == null
        ? '—'
        : L10nFormatters.formatDateTime(context, updatedAt.toLocal());
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_isEdit ? l10n.editProject : l10n.addProject, style: AppTheme.appTextStyle(context, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _boqCreationDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _boqCreationDate = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.projectBoqCreationDateRequired,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                  ),
                  child: Text(L10nFormatters.formatDateShort(context, _boqCreationDate)),
                ),
              ),
              if (_isEdit) ...[
                const SizedBox(height: AppTheme.spaceMd),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.projectLastEditDateLabel,
                    border: const OutlineInputBorder(),
                  ),
                  child: Text(lastEditStr),
                ),
              ],
              const SizedBox(height: AppTheme.spaceMd),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.nameEnglishRequired,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? l10n.required : null,
              ),
              const SizedBox(height: AppTheme.spaceMd),
              TextFormField(
                controller: _nameArController,
                decoration: InputDecoration(
                  labelText: l10n.nameArOptional,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              TextFormField(
                controller: _projectOwnerController,
                decoration: InputDecoration(
                  labelText: l10n.projectOwner,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              TextFormField(
                controller: _projectOwnerArController,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  labelText: l10n.projectOwnerArabic,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.description,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTheme.spaceLg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.productsQuantitiesHint,
                      style: AppTheme.appTextStyle(context, fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  TextButton(
                    onPressed: _allProducts.isEmpty ? null : _addProduct,
                    child: Text('+ ${l10n.add}'),
                  ),
                ],
              ),
              if (_selectedProducts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.noProductsAdded,
                    style: AppTheme.appTextStyle(context, fontSize: 14, color: AppTheme.textSecondary),
                  ),
                )
              else
                ..._selectedProducts.asMap().entries.map((e) {
                  final pid = e.value['productId'] as String?;
                  Product? resolvedProduct;
                  if (pid != null) {
                    try {
                      resolvedProduct = _allProducts.firstWhere((x) => x.id == pid);
                    } catch (_) {
                      resolvedProduct = null;
                    }
                  }
                  final manufacturer = resolvedProduct?.manufacturer?.trim() ??
                      (e.value['manufacturer'] as String?)?.trim();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localizedApiProductName(context, e.value['name']?.toString() ?? ''),
                                    style: AppTheme.appTextStyle(context, fontWeight: FontWeight.w600),
                                  ),
                                  if (manufacturer != null && manufacturer.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${l10n.manufacturer}: $manufacturer',
                                      style: AppTheme.appTextStyle(context, fontSize: 12, color: AppTheme.textSecondary),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    '${l10n.maxQty} ${e.value['quantity']}${(e.value['color'] as String?) != null ? ' • ${localizedVariantOrColorLabel(context, e.value['color'] as String)}' : ''}',
                                    style: AppTheme.appTextStyle(context, fontSize: 13, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () => _editProductQuantity(e.key),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: AppTheme.error, size: 20),
                                onPressed: () => _removeProduct(e.key),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              if (_isEdit) ...[
                const SizedBox(height: AppTheme.spaceMd),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: InputDecoration(
                    labelText: l10n.status,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 'active', child: Text(AppLocalizations.of(context)!.active)),
                    DropdownMenuItem(value: 'inactive', child: Text(AppLocalizations.of(context)!.inactive)),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'active'),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppTheme.spaceMd),
                  child: Text(_error!, style: AppTheme.appTextStyle(context, color: Colors.red)),
                ),
              const SizedBox(height: AppTheme.spaceXl),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(AppLocalizations.of(context)!.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Searchable product selector - tap to open a searchable list.
class _SearchableProductSelect extends StatefulWidget {
  final String label;
  final List<Product> products;
  final String? value;
  final String Function(Product) displayText;
  final ValueChanged<String?> onChanged;

  const _SearchableProductSelect({
    required this.label,
    required this.products,
    required this.value,
    required this.displayText,
    required this.onChanged,
  });

  @override
  State<_SearchableProductSelect> createState() => _SearchableProductSelectState();
}

class _SearchableProductSelectState extends State<_SearchableProductSelect> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<Product> get _filteredProducts {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return widget.products;
    return widget.products.where((p) {
      final name = p.name.toLowerCase();
      final displayAr = arabicDisplayNameForProduct(p).toLowerCase();
      final displayEn = englishDisplayNameForProduct(p).toLowerCase();
      final unit = p.unit.toLowerCase();
      final category = p.category.join(' ').toLowerCase();
      final displayCat = p.displayCategories(context).toLowerCase();
      final mfr = (p.manufacturer ?? '').toLowerCase();
      return name.contains(q) ||
          displayAr.contains(q) ||
          displayEn.contains(q) ||
          unit.contains(q) ||
          category.contains(q) ||
          displayCat.contains(q) ||
          mfr.contains(q);
    }).toList();
  }

  void _showSearchDialog() {
    _searchController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _searchFocusNode.requestFocus();
        });
        return StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filtered = _filteredProducts;
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, scrollController) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(ctx)!.searchProductsHint,
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            AppLocalizations.of(ctx)!.noResultsFor(_searchController.text),
                            style: AppTheme.appTextStyle(context, color: AppTheme.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final p = filtered[i];
                            final selected = p.id == widget.value;
                            final m = p.manufacturer?.trim();
                            return ListTile(
                              title: Text(
                                widget.displayText(p),
                                softWrap: true,
                                maxLines: null,
                                overflow: TextOverflow.clip,
                              ),
                              subtitle: m != null && m.isNotEmpty
                                  ? Text(
                                      '${AppLocalizations.of(context)!.manufacturer}: $m',
                                      style: AppTheme.appTextStyle(context, fontSize: 13, color: AppTheme.textSecondary),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              trailing: selected ? const Icon(Icons.check, color: AppTheme.primary) : null,
                              onTap: () {
                                widget.onChanged(p.id);
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      );
    },
    ).then((_) {
      _searchFocusNode.unfocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.products.cast<Product?>().firstWhere(
          (p) => p?.id == widget.value,
          orElse: () => null,
        );
    final display = product != null ? widget.displayText(product) : AppLocalizations.of(context)!.selectProduct;
    final l10n = AppLocalizations.of(context)!;
    final mClosed = product?.manufacturer?.trim();
    return InkWell(
      onTap: _showSearchDialog,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: product == null
            ? Text(
                display,
                style: AppTheme.appTextStyle(
                  context,
                  fontSize: 16,
                  color: Theme.of(context).hintColor,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    display,
                    style: AppTheme.appTextStyle(context, fontSize: 16),
                    softWrap: true,
                    maxLines: null,
                    overflow: TextOverflow.clip,
                  ),
                  if (mClosed != null && mClosed.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${l10n.manufacturer}: $mClosed',
                      style: AppTheme.appTextStyle(context, fontSize: 13, color: AppTheme.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
