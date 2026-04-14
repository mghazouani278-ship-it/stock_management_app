import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/supplementary_request.dart';
import '../../../widgets/connection_error_widget.dart';
import '../../../models/store.dart';
import '../../../services/api_service.dart';
import '../../../utils/embedded_ref_localized.dart';
import '../../../utils/l10n_ui_helpers.dart';
import '../../../utils/store_localized.dart';
import '../../../utils/product_localized.dart';

class SupplementaryRequestsListScreen extends StatefulWidget {
  const SupplementaryRequestsListScreen({super.key});

  @override
  State<SupplementaryRequestsListScreen> createState() => _SupplementaryRequestsListScreenState();
}

class _SupplementaryRequestsListScreenState extends State<SupplementaryRequestsListScreen> {
  final ApiService _apiService = ApiService();
  List<SupplementaryRequest> _requests = [];
  List<Store> _stores = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _apiService.get('/supplementary-requests');
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _requests = (res['data'] as List)
              .map((e) => SupplementaryRequest.fromJson(Map<String, dynamic>.from(e)))
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

  Future<void> _approveRequest(SupplementaryRequest req) async {
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
    final l10n = AppLocalizations.of(context)!;
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(l10n.approveSupplementaryRequest),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.selectStoreToDeduct),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: storeId,
                decoration: InputDecoration(labelText: l10n.storeRequired, border: const OutlineInputBorder()),
                items: _stores.map((s) => DropdownMenuItem(value: s.id, child: Text(s.displayName(context)))).toList(),
                onChanged: (v) => setD(() => storeId = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
              child: Text(l10n.approved),
            ),
          ],
        ),
      ),
    );
    if (approved != true || !mounted) return;
    try {
      await _apiService.put('/supplementary-requests/${req.id}/approve', {'store': storeId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.supplementaryRequestApproved), backgroundColor: Colors.green));
        _loadRequests();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    }
  }

  Future<void> _refuseRequest(SupplementaryRequest req) async {
    final l10nRefuse = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10nRefuse.refuseSupplementaryRequest),
        content: Text(l10nRefuse.refuseSupplementaryRequestQuestion),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10nRefuse.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10nRefuse.refused),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _apiService.put('/supplementary-requests/${req.id}/refuse', {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10nRefuse.supplementaryRequestRefused), backgroundColor: Colors.orange));
        _loadRequests();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    }
  }

  void _showDetails(SupplementaryRequest req) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.userRequestedAdditionalQuantities(
                          req.user == null
                              ? l10n.userFallback
                              : localizedDisplayUserName(context, req.user!.name, nameAr: req.user!.nameAr),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.red, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Chip(
                label: Text(localizedUiStatus(context, req.status), style: const TextStyle(fontSize: 12)),
                backgroundColor: req.status == 'pending'
                    ? Colors.red.withOpacity(0.2)
                    : req.status == 'approved'
                        ? Colors.green.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.2),
              ),
              if (req.project != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(l10n.projectLabel(req.project!.displayName(context)))),
              if (req.user != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.userLabel(localizedDisplayUserName(context, req.user!.name, nameAr: req.user!.nameAr)),
                  ),
                ),
              const SizedBox(height: 16),
              Text(l10n.productsAdditional, style: const TextStyle(fontWeight: FontWeight.bold)),
              ...req.products.map((p) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '  • ${localizedOrderProductDisplayName(ctx, p.name, p.product)}: ${p.quantity} ${l10n.extraQuantityPart('${p.extraQuantity}')} ${formatRawUnitForDisplay(p.unit)}',
                    ),
                  )),
              if (req.notes != null && req.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.notesLabel(req.notes!)),
              ],
              if (req.status == 'pending') ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _approveRequest(req);
                        },
                        style: FilledButton.styleFrom(backgroundColor: Colors.green),
                        child: Text(l10n.approved),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _refuseRequest(req);
                        },
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        child: Text(l10n.refused),
                      ),
                    ),
                  ],
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
        title: Text(AppLocalizations.of(context)!.supplementaryRequestsTitle),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _loadRequests)],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _requests.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null && _requests.isEmpty) {
      return ConnectionErrorWidget(message: _error!, onRetry: _loadRequests);
    }
    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.noSupplementaryRequests, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final req = _requests[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: req.status == 'pending' ? Colors.red.shade50 : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: req.status == 'pending' ? BorderSide(color: Colors.red.shade200, width: 2) : BorderSide.none,
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: req.status == 'pending' ? Colors.red : req.status == 'approved' ? Colors.green : Colors.grey,
                child: Icon(req.status == 'pending' ? Icons.pending : req.status == 'approved' ? Icons.check : Icons.close, color: Colors.white, size: 20),
              ),
              title: Text(
                req.project?.displayName(context) ?? AppLocalizations.of(context)!.requestLabel,
                style: TextStyle(fontWeight: FontWeight.bold, color: req.status == 'pending' ? Colors.red.shade900 : null),
              ),
              subtitle: Text(
                '${req.user == null ? AppLocalizations.of(context)!.userFallback : localizedDisplayUserName(context, req.user!.name, nameAr: req.user!.nameAr)} • ${localizedUiStatus(context, req.status)}',
                style: TextStyle(color: req.status == 'pending' ? Colors.red.shade700 : null),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDetails(req),
            ),
          );
        },
      ),
    );
  }
}
