import 'package:flutter/material.dart';
import '../../../utils/product_localized.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/api_service.dart';
import '../../../widgets/connection_error_widget.dart';

class WarehouseStockSummaryScreen extends StatefulWidget {
  const WarehouseStockSummaryScreen({super.key});

  @override
  State<WarehouseStockSummaryScreen> createState() => _WarehouseStockSummaryScreenState();
}

class _WarehouseStockSummaryScreenState extends State<WarehouseStockSummaryScreen> {
  final ApiService _apiService = ApiService();
  int _totalQuantity = 0;
  Map<String, Map<String, dynamic>> _byProduct = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _apiService.get('/reports/stock-summary');
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        setState(() {
          _totalQuantity = data['totalQuantity'] ?? 0;
          final raw = data['byProduct'] as Map<String, dynamic>? ?? {};
          _byProduct = raw.map((k, v) {
            if (v is Map) {
              return MapEntry(k, Map<String, dynamic>.from(v));
            }
            return MapEntry(k, {'quantity': v, 'name': k});
          });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.totalGlobalStock),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadSummary,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ConnectionErrorWidget(message: _error!, onRetry: _loadSummary);
    }
    return RefreshIndicator(
      onRefresh: _loadSummary,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      'Total Global Quantity',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_totalQuantity',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'View only',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_byProduct.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'By Product',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ...(_byProduct.entries.toList()
                ..sort((a, b) {
                  final nameA = (a.value['name'] ?? a.key).toString().toLowerCase();
                  final nameB = (b.value['name'] ?? b.key).toString().toLowerCase();
                  return nameA.compareTo(nameB);
                })).map((e) {
                final name = e.value['name'] ?? e.key;
                final qty = e.value['quantity'] ?? e.value;
                final titleStr = name is String ? name : e.key.toString();
                return Card(
                  child: ListTile(
                    title: Text(localizedApiProductName(context, titleStr)),
                    trailing: Text(
                      '$qty',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
