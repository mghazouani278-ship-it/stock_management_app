import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/return_model.dart';
import '../../../models/store.dart';
import '../../../services/api_service.dart';
import '../../../widgets/connection_error_widget.dart';
import '../../../utils/embedded_ref_localized.dart';
import '../../../utils/l10n_ui_helpers.dart';
import '../../../utils/store_localized.dart';

class WarehouseReturnsScreen extends StatefulWidget {
  const WarehouseReturnsScreen({super.key});

  @override
  State<WarehouseReturnsScreen> createState() => _WarehouseReturnsScreenState();
}

class _WarehouseReturnsScreenState extends State<WarehouseReturnsScreen> {
  final ApiService _apiService = ApiService();
  List<ReturnModel> _returns = [];
  List<Store> _stores = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReturns();
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

  Future<void> _approveReturn(ReturnModel returnItem) async {
    if (_stores.isEmpty) {
      try {
        final res = await _apiService.get('/stores');
        if (res['success'] == true && res['data'] != null) {
          _stores = (res['data'] as List).map((e) => Store.fromJson(Map<String, dynamic>.from(e))).toList();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
        return;
      }
    }
    if (_stores.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.noStoresAvailable)));
      return;
    }
    String? storeId = _stores.first.id;
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(AppLocalizations.of(ctx)!.approveReturn),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(ctx)!.selectStoreUndamagedProducts),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: storeId,
                decoration: InputDecoration(labelText: AppLocalizations.of(ctx)!.storeRequired, border: const OutlineInputBorder()),
                items: _stores.map((s) => DropdownMenuItem(value: s.id, child: Text(s.displayName(context)))).toList(),
                onChanged: (v) => setD(() => storeId = v),
              ),
              const SizedBox(height: 12),
              Text(AppLocalizations.of(ctx)!.goodStoreOriginDamagedSelected, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(ctx)!.cancel)),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppLocalizations.of(ctx)!.approve),
            ),
          ],
        ),
      ),
    );
    if (approved != true || !mounted) return;
    try {
      await _apiService.put('/returns/${returnItem.id}/approve', {'store': storeId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.returnApprovedUndamagedAdded), backgroundColor: Colors.green));
        _loadReturns();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    }
  }

  void _showDetails(ReturnModel returnItem) {
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
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(
                returnItem.project != null
                    ? AppLocalizations.of(ctx)!.returnWithProject(returnItem.project!.displayName(ctx))
                    : AppLocalizations.of(ctx)!.returnItem,
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(localizedUiStatus(ctx, returnItem.status), style: const TextStyle(fontSize: 12)),
                backgroundColor: (returnItem.status == 'approved' ? Colors.green : returnItem.status == 'rejected' ? Colors.red : Colors.orange).withOpacity(0.2),
              ),
              if (returnItem.project != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(AppLocalizations.of(ctx)!.projectLabel(returnItem.project!.displayName(ctx)))),
              if (returnItem.user != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    AppLocalizations.of(ctx)!.userLabel(
                      localizedDisplayUserName(ctx, returnItem.user!.name, nameAr: returnItem.user!.nameAr),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(ctx)!.productsLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              ...returnItem.products.map((p) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(formatReturnProductLine(ctx, productName: p.productName, quantity: p.quantity, condition: p.condition, color: p.color)),
                  )),
              if (returnItem.notes != null && returnItem.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(AppLocalizations.of(ctx)!.notesLabel(returnItem.notes ?? '')),
              ],
              if (returnItem.status == 'pending') ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _approveReturn(returnItem);
                    },
                    icon: const Icon(Icons.check_circle),
                    label: Text(AppLocalizations.of(ctx)!.approveAddUndamagedWarehouse),
                  ),
                ),
              ],
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
        title: Text(AppLocalizations.of(context)!.returns),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _loadReturns)],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _returns.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null && _returns.isEmpty) {
      return ConnectionErrorWidget(message: _error!, onRetry: _loadReturns);
    }
    if (_returns.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noReturnsYet, textAlign: TextAlign.center));
    }
    return RefreshIndicator(
      onRefresh: _loadReturns,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _returns.length,
        itemBuilder: (context, index) {
          final r = _returns[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: r.status == 'approved' ? Colors.green : r.status == 'rejected' ? Colors.red : Colors.orange,
                child: Icon(r.status == 'approved' ? Icons.check : r.status == 'rejected' ? Icons.close : Icons.pending, color: Colors.white, size: 20),
              ),
              title: Text(r.project?.displayName(context) ?? AppLocalizations.of(context)!.returnItem, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (r.products.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        formatReturnListPreview(context, r.products),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  Text(localizedUiStatus(context, r.status)),
                ],
              ),
              isThreeLine: r.products.isNotEmpty,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDetails(r),
            ),
          );
        },
      ),
    );
  }
}
