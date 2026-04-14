import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/damaged_product.dart';
import '../../../models/product.dart';
import '../../../models/store.dart';
import '../../../models/user.dart';
import '../../../services/api_service.dart';
import '../../../widgets/connection_error_widget.dart';
import '../../../utils/l10n_ui_helpers.dart';
import '../../../utils/store_localized.dart';
import '../../../utils/project_localized.dart';
import '../../../utils/product_localized.dart';

class WarehouseDamagedProductsScreen extends StatefulWidget {
  const WarehouseDamagedProductsScreen({super.key});

  @override
  State<WarehouseDamagedProductsScreen> createState() => _WarehouseDamagedProductsScreenState();
}

class _WarehouseDamagedProductsScreenState extends State<WarehouseDamagedProductsScreen> {
  final ApiService _apiService = ApiService();
  List<DamagedProduct> _items = [];
  List<Product> _products = [];
  List<Store> _stores = [];
  List<Project> _projects = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDamagedProducts();
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

  Future<void> _showAddForm() async {
    if (_products.isEmpty || _stores.isEmpty || _projects.isEmpty) {
      try {
        final results = await Future.wait([
          _apiService.get('/products'),
          _apiService.get('/stores'),
          _apiService.get('/projects'),
        ]);
        if (results[0]['success'] == true && results[0]['data'] != null) {
          _products = (results[0]['data'] as List).map((e) => Product.fromJson(Map<String, dynamic>.from(e))).toList();
        }
        if (results[1]['success'] == true && results[1]['data'] != null) {
          _stores = (results[1]['data'] as List).map((e) => Store.fromJson(Map<String, dynamic>.from(e))).toList();
        }
        if (results[2]['success'] == true && results[2]['data'] != null) {
          _projects = (results[2]['data'] as List).map((e) => Project.fromJson(Map<String, dynamic>.from(e))).toList();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
        return;
      }
    }
    if (_products.isEmpty || _stores.isEmpty || _projects.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.addProductsStoresFirst)));
      return;
    }
    String? productId = _products.first.id;
    String? storeId = _stores.first.id;
    String? projectId = _projects.first.id;
    final qtyController = TextEditingController(text: '1');
    final reasonController = TextEditingController();
    final notesController = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final l10n = AppLocalizations.of(ctx)!;
          return AlertDialog(
          title: Text(l10n.addDamagedProduct),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: productId,
                  decoration: InputDecoration(labelText: '${l10n.product} *', border: const OutlineInputBorder()),
                  items: _products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.displayName(context)))).toList(),
                  onChanged: (v) => setD(() => productId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: projectId,
                  decoration: InputDecoration(labelText: '${l10n.project} *', border: const OutlineInputBorder()),
                  items: _projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.displayName(context)))).toList(),
                  onChanged: (v) => setD(() => projectId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: storeId,
                  decoration: InputDecoration(labelText: '${l10n.store} *', border: const OutlineInputBorder()),
                  items: _stores.map((s) => DropdownMenuItem(value: s.id, child: Text(s.displayName(context)))).toList(),
                  onChanged: (v) => setD(() => storeId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: '${l10n.quantity} *', border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(labelText: l10n.reasonRequired, border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(labelText: l10n.notesOptional, border: const OutlineInputBorder()),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () {
                if (productId != null && storeId != null && projectId != null &&
                    (int.tryParse(qtyController.text) ?? 0) > 0 &&
                    reasonController.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, true);
                }
              },
              child: Text(l10n.add),
            ),
          ],
        );
        },
      ),
    );
    if (added != true || !mounted) return;
    try {
      await _apiService.post('/damaged-products', {
        'product': productId,
        'store': storeId,
        'projectId': projectId,
        'quantity': int.parse(qtyController.text),
        'reason': reasonController.text.trim(),
        'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.damagedProductAdded), backgroundColor: Colors.green));
        _loadDamagedProducts();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    }
  }

  Future<void> _approveDamaged(DamagedProduct item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.approveDamagedProduct),
        content: Text(AppLocalizations.of(context)!.approveDamagedProductQuestion(
          item.product != null ? localizedApiProductName(context, item.product!.name) : AppLocalizations.of(context)!.product,
          item.quantity,
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context)!.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppLocalizations.of(context)!.approve)),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _apiService.put('/damaged-products/${item.id}/approve', {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.approved), backgroundColor: Colors.green));
        _loadDamagedProducts();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
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
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  item.product != null ? localizedApiProductName(context, item.product!.name) : l10n.damagedProduct,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(l10n.qtyReasonStatusLine('${item.quantity}', localizedDamageReason(context, item.reason), localizedUiStatus(context, item.status))),
                if (item.store != null) ...[
                  const SizedBox(height: 8),
                  Text('${l10n.store}: ${item.store!.displayName(context)}'),
                ],
                if (item.project != null) ...[
                  const SizedBox(height: 4),
                  Text('${l10n.project}: ${item.project!.displayName(context)}'),
                ],
                if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(l10n.notesLabel(localizedDamagedNotes(context, item.notes))),
                ],
                if (item.approvedBy != null) ...[
                  const SizedBox(height: 8),
                  Text(l10n.approvedByLabel(localizedDisplayUserName(context, item.approvedBy!.name, nameAr: item.approvedBy!.nameAr))),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.damagedProducts),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _loadDamagedProducts),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddForm,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
    if (_loading && _items.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null && _items.isEmpty) {
      return ConnectionErrorWidget(message: _error!, onRetry: _loadDamagedProducts);
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.noDamagedProducts, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _showAddForm, icon: const Icon(Icons.add), label: Text(AppLocalizations.of(context)!.addDamagedProduct)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadDamagedProducts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: item.status == 'approved' ? Colors.green : Colors.orange,
                child: Icon(item.status == 'approved' ? Icons.check : Icons.pending, color: Colors.white),
              ),
              title: Text(
                item.product != null ? localizedApiProductName(context, item.product!.name) : l10n.product,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(l10n.qtyReasonStatusLine('${item.quantity}', localizedDamageReason(context, item.reason), localizedUiStatus(context, item.status))),
              trailing: item.status == 'pending'
                  ? IconButton(
                      icon: const Icon(Icons.check_circle),
                      onPressed: () => _approveDamaged(item),
                      tooltip: AppLocalizations.of(context)!.approve,
                    )
                  : null,
              onTap: () => _showDetails(item),
            ),
          );
        },
      ),
    );
  }
}
