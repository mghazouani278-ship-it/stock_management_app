import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../widgets/connection_error_widget.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../../../utils/product_localized.dart';

class ReturnFormScreen extends StatefulWidget {
  const ReturnFormScreen({super.key});

  @override
  State<ReturnFormScreen> createState() => _ReturnFormScreenState();
}

class _ReturnFormScreenState extends State<ReturnFormScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _projectProducts = [];
  final List<Map<String, dynamic>> _selectedProducts = [];
  final Map<String, TextEditingController> _quantityControllers = {};
  final Map<String, String> _conditionControllers = {};
  final _notesController = TextEditingController();
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadProjectProducts();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final c in _quantityControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProjectProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final projectId = authProvider.user?.project?.id;
      if (projectId == null || projectId.isEmpty) {
        setState(() {
          _loading = false;
          _error = AppLocalizations.of(context)!.notAssignedToProject;
        });
        return;
      }
      final res = await _apiService.get('/projects/$projectId');
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        final products = data['products'] as List? ?? [];
        setState(() {
          _projectProducts = products
              .map((p) => Map<String, dynamic>.from(p as Map))
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

  String _productKey(String productId, String? color) => '${productId}|${color ?? ''}';

  Future<void> _showAddProductDialog() async {
    if (_projectProducts.isEmpty) return;
    String? selectedKey;
    final qtyController = TextEditingController(text: '1');
    String condition = 'good';
    final added = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final alreadyAddedKeys = _selectedProducts.map((s) => _productKey(s['productId'] as String? ?? '', s['color'] as String?)).toSet();
          final available = _projectProducts.where((p) {
            final id = p['product']?['id'] ?? p['product']?['_id'] ?? '';
            final color = p['color']?.toString();
            return !alreadyAddedKeys.contains(_productKey(id, color));
          }).toList();
          if (available.isEmpty) {
            return AlertDialog(
              title: Text(AppLocalizations.of(ctx)!.addProductSmall),
              content: Text(AppLocalizations.of(ctx)!.allProductsAdded),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx, null), child: Text(AppLocalizations.of(ctx)!.ok))],
            );
          }
          selectedKey ??= _productKey(
            available.first['product']?['id'] ?? available.first['product']?['_id'] ?? '',
            available.first['color']?.toString(),
          );
          final selected = available.firstWhere(
            (p) => _productKey(p['product']?['id'] ?? p['product']?['_id'] ?? '', p['color']?.toString()) == selectedKey,
            orElse: () => available.first,
          );
          final maxQty = selected['allowedQuantity'] ?? selected['allowed_quantity'] ?? 0;
          final unit = formatRawUnitForDisplay(selected['product']?['unit']?.toString());
          return AlertDialog(
            title: Text(AppLocalizations.of(ctx)!.addProductToReturn),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedKey,
                    decoration: InputDecoration(labelText: AppLocalizations.of(ctx)!.product, border: const OutlineInputBorder()),
                    items: available.map<DropdownMenuItem<String>>((p) {
                      final id = p['product']?['id'] ?? p['product']?['_id'] ?? '';
                      final rawN = p['product']?['name']?.toString();
                      final n = rawN != null && rawN.trim().isNotEmpty
                          ? localizedApiProductName(ctx, rawN)
                          : AppLocalizations.of(ctx)!.product;
                      final c = p['color']?.toString();
                      final key = _productKey(id, c);
                      return DropdownMenuItem(
                        value: key,
                        child: Text(
                          c != null && c.isNotEmpty
                              ? '$n (${localizedVariantOrColorLabel(ctx, c)})'
                              : n,
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setDialogState(() => selectedKey = v),
                  ),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(ctx)!.maxQtyFormatted('$maxQty', unit), style: AppTheme.appTextStyle(ctx, fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: AppLocalizations.of(ctx)!.quantity, border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: condition,
                    decoration: InputDecoration(labelText: AppLocalizations.of(ctx)!.conditionLabel, border: const OutlineInputBorder()),
                    items: [
                      DropdownMenuItem(value: 'good', child: Text(AppLocalizations.of(ctx)!.goodCondition)),
                      DropdownMenuItem(value: 'damaged', child: Text(AppLocalizations.of(ctx)!.damagedCondition)),
                    ],
                    onChanged: (v) => setDialogState(() => condition = v ?? 'good'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, null), child: Text(AppLocalizations.of(ctx)!.cancel)),
              FilledButton(
                onPressed: () {
                  final q = int.tryParse(qtyController.text) ?? 0;
                  if (q > 0 && selectedKey != null) {
                    final parts = selectedKey!.split('|');
                    final pid = parts.isNotEmpty ? parts[0] : '';
                    final color = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
                    Navigator.pop(ctx, {'productId': pid, 'quantity': q, 'condition': condition, 'color': color});
                  }
                },
                child: Text(AppLocalizations.of(ctx)!.add),
              ),
            ],
          );
        },
      ),
    );
    qtyController.dispose();
    final result = added;
    if (result != null && mounted) {
      final productId = result['productId'] as String?;
      final qty = result['quantity'] as int? ?? 0;
      final cond = result['condition'] as String? ?? 'good';
      final color = result['color'] as String?;
      if (productId != null && qty > 0) {
        final selected = _projectProducts.firstWhere(
          (p) => (p['product']?['id'] ?? p['product']?['_id'] ?? '') == productId && (p['color']?.toString() ?? '') == (color ?? ''),
        );
        final id = selected['product']?['id'] ?? selected['product']?['_id'] ?? '';
        final name = selected['product']?['name'] ?? AppLocalizations.of(context)!.product;
        final unit = selected['product']?['unit'] ?? '';
        final maxQty = selected['allowedQuantity'] ?? selected['allowed_quantity'] ?? 0;
        final ctrl = TextEditingController(text: qty.toString());
        final key = _productKey(id, color);
        _quantityControllers[key] = ctrl;
        _conditionControllers[key] = cond;
        setState(() {
          _selectedProducts.add({
            'productId': id,
            'name': name,
            'unit': unit,
            'maxQty': maxQty,
            'color': color,
            'controller': ctrl,
          });
        });
      }
    }
  }

  void _removeProduct(String productId, [String? color]) {
    final key = _productKey(productId, color);
    _quantityControllers[key]?.dispose();
    _quantityControllers.remove(key);
    _conditionControllers.remove(key);
    setState(() => _selectedProducts.removeWhere((p) => (p['productId'] == productId) && (p['color'] as String? ?? '') == (color ?? '')));
  }

  Future<void> _submitReturn() async {
    final products = <Map<String, dynamic>>[];
    for (final p in _selectedProducts) {
      final productId = p['productId'] as String? ?? '';
      final ctrl = p['controller'] as TextEditingController?;
      final qty = int.tryParse(ctrl?.text ?? '0') ?? 0;
      if (qty > 0) {
        final key = _productKey(productId, p['color'] as String?);
        final map = <String, dynamic>{
          'product': productId,
          'quantity': qty,
          'condition': _conditionControllers[key] ?? 'good',
        };
        final rawColor = p['color'];
        if (rawColor != null && rawColor.toString().trim().isNotEmpty) {
          map['color'] = rawColor.toString().trim();
        }
        products.add(map);
      }
    }
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.addAtLeastOneProduct)),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await _apiService.post('/returns', {
        'products': products,
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.returnSubmittedSuccess), backgroundColor: AppTheme.success),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.newReturn, style: AppTheme.appTextStyle(context, fontWeight: FontWeight.w600)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_error != null) {
      return ConnectionErrorWidget(message: _error!, onRetry: _loadProjectProducts);
    }
    if (_projectProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.undo_rounded, size: 64, color: AppTheme.textTertiary),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              AppLocalizations.of(context)!.noProductsAvailableForProject,
              textAlign: TextAlign.center,
              style: AppTheme.appTextStyle(context, fontSize: 16, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.contactAdminAddProducts,
              textAlign: TextAlign.center,
              style: AppTheme.appTextStyle(context, fontSize: 14, color: AppTheme.textTertiary),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.selectProductsToReturn,
                  style: AppTheme.appTextStyle(context, fontSize: 14, color: AppTheme.textSecondary),
                ),
              ),
              FilledButton(
                onPressed: _showAddProductDialog,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
                ),
                child: Text(AppLocalizations.of(context)!.add),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          ..._selectedProducts.map((p) {
            final productId = p['productId'] as String? ?? '';
            final nameEn = p['name'] as String? ?? '';
            final col = p['color'] as String?;
            final name = nameEn.isNotEmpty
                ? (col != null && col.isNotEmpty
                    ? '${localizedApiProductName(context, nameEn)} (${localizedVariantOrColorLabel(context, col)})'
                    : localizedApiProductName(context, nameEn))
                : AppLocalizations.of(context)!.product;
            final unit = formatRawUnitForDisplay(p['unit'] as String?);
            final maxQty = p['maxQty'] as int? ?? 0;
            final ctrl = p['controller'] as TextEditingController?;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
              child: AppCard(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: AppTheme.appTextStyle(context, fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                              ),
                              Text(
                                AppLocalizations.of(context)!.maxQtyFormatted('$maxQty', unit),
                                style: AppTheme.appTextStyle(context, fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: ctrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!.qtyShort,
                              hintText: '0',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: AppTheme.error),
                          onPressed: () => _removeProduct(productId, p['color'] as String?),
                          tooltip: AppLocalizations.of(context)!.removeTooltip,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _conditionControllers[_productKey(productId, p['color'] as String?)] ?? 'good',
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.conditionLabel,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        DropdownMenuItem(value: 'good', child: Text(AppLocalizations.of(context)!.goodCondition)),
                        DropdownMenuItem(value: 'damaged', child: Text(AppLocalizations.of(context)!.damagedCondition)),
                      ],
                      onChanged: (v) => setState(() => _conditionControllers[_productKey(productId, p['color'] as String?)] = v ?? 'good'),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: AppTheme.spaceMd),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.notesOptional,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            ),
          ),
          const SizedBox(height: AppTheme.spaceXl),
          FilledButton(
            onPressed: _submitting ? null : _submitReturn,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
              backgroundColor: AppTheme.primary,
            ),
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(AppLocalizations.of(context)!.submitReturn, style: AppTheme.appTextStyle(context, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
