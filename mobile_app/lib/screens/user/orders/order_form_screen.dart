import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/l10n_formatters.dart';
import '../../../utils/product_localized.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../widgets/connection_error_widget.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_card.dart';

class OrderFormScreen extends StatefulWidget {
  const OrderFormScreen({super.key, this.projectId});

  /// When set (e.g. admin creating an order), loads this project; otherwise uses the signed-in user's project.
  final String? projectId;

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _projectProducts = [];
  final List<Map<String, dynamic>> _selectedProducts = [];
  final Map<String, TextEditingController> _quantityControllers = {};
  final _notesController = TextEditingController();
  DateTime _orderDate = DateTime.now();
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
      final projectId = widget.projectId ?? authProvider.user?.project?.id;
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

  int _parseQuantity(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  /// Remaining project quantity allocable to new orders for this line.
  /// Prefer requested - distributed when available (more reliable than stale allowedQuantity).
  int _remainingAllocatedFor(Map<String, dynamic> p) {
    final allowed = _parseQuantity(p['allowedQuantity'] ?? p['allowed_quantity']);
    final requested = _parseQuantity(p['requestedQuantity'] ?? p['requested_quantity']);
    final distributed = _parseQuantity(p['distributedQuantity'] ?? p['distributed_quantity']);
    if (requested > 0) {
      final rem = requested - distributed;
      if (rem <= 0) return 0;
      return rem > requested ? requested : rem;
    }
    return allowed < 0 ? 0 : allowed;
  }

  Future<void> _showAddProductDialog() async {
    if (_projectProducts.isEmpty) return;
    final alreadyAddedKeys = _selectedProducts.map((s) => _productKey(s['productId'] as String? ?? '', s['color'] as String?)).toSet();
    final available = _projectProducts.where((p) {
      final id = p['product']?['id'] ?? p['product']?['_id'] ?? '';
      final color = p['color']?.toString();
      return !alreadyAddedKeys.contains(_productKey(id, color));
    }).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.allProductsAdded)));
      return;
    }
    const initialQty = 0;
    String? selectedKey;
    final qtyController = TextEditingController(text: initialQty.toString());
    final added = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final l10n = AppLocalizations.of(ctx)!;
          selectedKey ??= _productKey(
            available.first['product']?['id'] ?? available.first['product']?['_id'] ?? '',
            available.first['color']?.toString(),
          );
          final selected = available.firstWhere(
            (p) => _productKey(p['product']?['id'] ?? p['product']?['_id'] ?? '', p['color']?.toString()) == selectedKey,
            orElse: () => available.first,
          );
          final allowed = _remainingAllocatedFor(selected);
          final unit = selected['product']?['unit'] ?? '';
          return AlertDialog(
            title: Text(l10n.addProductSmall),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedKey,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.product, border: const OutlineInputBorder()),
                    items: available.map<DropdownMenuItem<String>>((p) {
                      final id = p['product']?['id'] ?? p['product']?['_id'] ?? '';
                      final rawN = p['product']?['name']?.toString();
                      final n = rawN != null && rawN.trim().isNotEmpty
                          ? localizedApiProductName(ctx, rawN)
                          : l10n.product;
                      final c = p['color']?.toString();
                      final key = _productKey(id, c);
                      final a = _remainingAllocatedFor(p);
                      final label = c != null && c.isNotEmpty
                          ? '$n (${localizedVariantOrColorLabel(ctx, c)})'
                          : n;
                      final suffix = l10n.allocatedDropdownSuffix('$a');
                      return DropdownMenuItem(
                        value: key,
                        child: Text(
                          '$label$suffix',
                          softWrap: true,
                          maxLines: null,
                          overflow: TextOverflow.clip,
                        ),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() {
                          selectedKey = v;
                          qtyController.text = '0';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.allocatedWithUnit('$allowed', formatRawUnitForDisplay(unit.toString())),
                    style: AppTheme.appTextStyle(context, fontSize: 13, fontWeight: FontWeight.w500, color: allowed > 0 ? AppTheme.primary : AppTheme.warning),
                  ),
                  Text(
                    l10n.supplementaryRequestMoreHint,
                    style: AppTheme.appTextStyle(context, fontSize: 12, color: AppTheme.textTertiary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.quantity,
                      hintText: l10n.orderQuantitySupplementaryHint('${allowed + 1}'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, null), child: Text(l10n.cancel)),
              FilledButton(
                  onPressed: () {
                  var q = int.tryParse(qtyController.text) ?? 0;
                  if (q <= 0 && allowed > 0) q = allowed;
                  if (q > 0 && selectedKey != null) {
                    final parts = selectedKey!.split('|');
                    final pid = parts.isNotEmpty ? parts[0] : '';
                    final color = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
                    Navigator.pop(ctx, {'productId': pid, 'quantity': q, 'color': color});
                  }
                },
                child: Text(l10n.add),
              ),
            ],
          );
        },
      ),
    );
    qtyController.dispose();
    final result = added;
    if (result != null && mounted) {
      final pid = result['productId'] as String?;
      final qty = result['quantity'] as int? ?? 0;
      final color = result['color'] as String?;
      if (pid != null && qty > 0) {
        final selected = _projectProducts.firstWhere(
          (p) => (p['product']?['id'] ?? p['product']?['_id'] ?? '') == pid && (p['color']?.toString() ?? '') == (color ?? ''),
        );
        final id = selected['product']?['id'] ?? selected['product']?['_id'] ?? '';
        final rawSel = selected['product']?['name']?.toString();
        final name = rawSel != null && rawSel.trim().isNotEmpty
            ? rawSel.trim()
            : AppLocalizations.of(context)!.product;
        final unit = selected['product']?['unit'] ?? '';
        final sa = _remainingAllocatedFor(selected);
        final ctrl = TextEditingController(text: qty.toString());
        final key = _productKey(id, color);
        _quantityControllers[key] = ctrl;
        setState(() {
          _selectedProducts.add({
            'productId': id,
            'name': name,
            'unit': unit,
            'allowedQuantity': sa,
            'quantity': qty,
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
    setState(() => _selectedProducts.removeWhere((p) => (p['productId'] == productId) && (p['color'] as String? ?? '') == (color ?? '')));
  }

  Future<void> _submitOrder() async {
    final products = <Map<String, dynamic>>[];
    for (final p in _selectedProducts) {
      final productId = p['productId'] as String? ?? '';
      final ctrl = p['controller'] as TextEditingController?;
      final qty = int.tryParse(ctrl?.text ?? '0') ?? 0;
      if (qty > 0) {
        final map = {'product': productId, 'quantity': qty};
        final color = p['color'] as String?;
        if (color != null && color.isNotEmpty) map['color'] = color;
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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final effectiveProjectId = widget.projectId ?? authProvider.user?.project?.id;
      final body = <String, dynamic>{
        'products': products,
        'orderDate': _orderDate.toIso8601String().split('T')[0],
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      };
      if (authProvider.isAdmin && effectiveProjectId != null && effectiveProjectId.isNotEmpty) {
        body['projectId'] = effectiveProjectId;
      }
      await _apiService.post('/orders', body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.orderPlacedSuccess), backgroundColor: AppTheme.success),
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
        title: Text(AppLocalizations.of(context)!.newOrder, style: AppTheme.appTextStyle(context, fontWeight: FontWeight.w600)),
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
    final l10n = AppLocalizations.of(context)!;
    if (_projectProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_rounded, size: 64, color: AppTheme.textTertiary),
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
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _orderDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _orderDate = picked);
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.orderDateRequired,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
              child: Text(
                L10nFormatters.formatDateShort(context, _orderDate),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.selectProductsQuantities,
                  style: AppTheme.appTextStyle(context, fontSize: 14, color: AppTheme.textSecondary),
                ),
              ),
              FilledButton.icon(
                onPressed: _showAddProductDialog,
                icon: const Icon(Icons.add, size: 20),
                label: Text(AppLocalizations.of(context)!.add),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          ..._selectedProducts.map((p) {
            final productId = p['productId'] as String? ?? '';
            final rawList = p['name'] as String?;
            final col = p['color'] as String?;
            final name = rawList != null && rawList.trim().isNotEmpty
                ? (col != null && col.isNotEmpty
                    ? '${localizedApiProductName(context, rawList)} (${localizedVariantOrColorLabel(context, col)})'
                    : localizedApiProductName(context, rawList))
                : l10n.product;
            final unit = formatRawUnitForDisplay(p['unit'] as String?);
            final allowed = _parseQuantity(p['allowedQuantity'] ?? p['allowed_quantity']);
            final ctrl = p['controller'] as TextEditingController?;
            final qty = int.tryParse(ctrl?.text ?? '0') ?? 0;
            final isSupplementary = qty > allowed && allowed >= 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
              child: AppCard(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: AppTheme.appTextStyle(context, fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                ),
                              ),
                              if (isSupplementary)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.warning.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    l10n.supplementary,
                                    style: AppTheme.appTextStyle(context, fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.warning),
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            isSupplementary
                                ? l10n.allocatedSummaryWithExtra('$allowed', unit, '${qty - allowed}')
                                : l10n.allocatedWithUnit('$allowed', unit),
                            style: AppTheme.appTextStyle(context, fontSize: 12, fontWeight: FontWeight.w500, color: allowed > 0 ? AppTheme.primary : AppTheme.warning),
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
                          labelText: l10n.qtyShort,
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
                      tooltip: l10n.removeTooltip,
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
              labelText: l10n.notesOptional,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            ),
          ),
          const SizedBox(height: AppTheme.spaceXl),
          FilledButton(
            onPressed: _submitting ? null : _submitOrder,
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
                : Text(AppLocalizations.of(context)!.placeOrder, style: AppTheme.appTextStyle(context, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
