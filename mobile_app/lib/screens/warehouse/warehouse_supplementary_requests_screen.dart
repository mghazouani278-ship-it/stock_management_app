import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/supplementary_request.dart';
import '../../services/api_service.dart';
import '../../widgets/connection_error_widget.dart';
import '../../utils/embedded_ref_localized.dart';
import '../../utils/l10n_ui_helpers.dart';
import '../../utils/product_localized.dart';

/// Warehouse view: supplementary requests in red (read-only, no approve/refuse)
class WarehouseSupplementaryRequestsScreen extends StatefulWidget {
  const WarehouseSupplementaryRequestsScreen({super.key});

  @override
  State<WarehouseSupplementaryRequestsScreen> createState() => _WarehouseSupplementaryRequestsScreenState();
}

class _WarehouseSupplementaryRequestsScreenState extends State<WarehouseSupplementaryRequestsScreen> {
  final ApiService _apiService = ApiService();
  List<SupplementaryRequest> _requests = [];
  List<Map<String, dynamic>> _statusNotifications = [];
  bool _loading = true;
  bool _loadingNotifications = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
    _loadStatusNotifications();
    _markNotificationsRead();
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

  Future<void> _loadStatusNotifications() async {
    setState(() => _loadingNotifications = true);
    try {
      final res = await _apiService.get('/supplementary-notifications/warehouse');
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
      setState(() => _loadingNotifications = false);
    }
  }

  Future<void> _markNotificationsRead() async {
    try {
      await _apiService.put('/supplementary-notifications/warehouse/read', {});
      if (mounted) _loadStatusNotifications();
    } catch (_) {}
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
                      '  • ${localizedOrderProductDisplayName(context, p.name, p.product)}: ${p.quantity} ${l10n.extraQuantityPart('${p.extraQuantity}')} ${formatRawUnitForDisplay(p.unit)}',
                    ),
                  )),
              if (req.notes != null && req.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context)!.notesLabel(req.notes ?? '')),
              ],
              const SizedBox(height: 16),
              Text(
                l10n.validationRequiredByAdmin,
                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
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
        title: Text(AppLocalizations.of(context)!.supplementaryRequestsTitle),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : () async {
              await _loadRequests();
              await _loadStatusNotifications();
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _requests.isEmpty && _statusNotifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _requests.isEmpty && _statusNotifications.isEmpty) {
      return ConnectionErrorWidget(message: _error!, onRetry: _loadRequests);
    }
    if (_requests.isEmpty && _statusNotifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await _loadRequests();
          await _loadStatusNotifications();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context)!.noSupplementaryRequests, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await _loadRequests();
        await _loadStatusNotifications();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_statusNotifications.isNotEmpty) ...[
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
                    final isApproved = status == 'approved';
                    final projectName = n['projectName'] ?? '';
                    final userName = n['userName'] ?? '';
                    final productSummary = n['productSummary'] ?? '';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isApproved
                          ? Colors.green.withOpacity(0.08)
                          : Colors.red.withOpacity(0.08),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isApproved ? Colors.green : Colors.red,
                          child: Icon(
                            isApproved ? Icons.check : Icons.close,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          isApproved
                              ? AppLocalizations.of(context)!.supplementaryRequestApproved
                              : AppLocalizations.of(context)!.supplementaryRequestRefused,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (projectName.isNotEmpty || userName.isNotEmpty)
                              Text('${projectName.isNotEmpty ? projectName : ''}${projectName.isNotEmpty && userName.isNotEmpty ? ' • ' : ''}${userName.isNotEmpty ? userName : ''}'),
                            if (productSummary.isNotEmpty)
                              Text(productSummary, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
          ..._requests.map((req) => Card(
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
                req.project?.displayName(context) ?? 'Request',
                style: TextStyle(fontWeight: FontWeight.bold, color: req.status == 'pending' ? Colors.red.shade900 : null),
              ),
              subtitle: Text(
                '${req.user == null ? AppLocalizations.of(context)!.userFallback : localizedDisplayUserName(context, req.user!.name, nameAr: req.user!.nameAr)} • ${req.status}',
                style: TextStyle(color: req.status == 'pending' ? Colors.red.shade700 : null),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDetails(req),
            ),
          )),
        ],
      ),
    );
  }
}
