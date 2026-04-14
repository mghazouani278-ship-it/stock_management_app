import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/store.dart';
import '../../../services/api_service.dart';
import '../../../utils/maps_launch.dart';
import '../../../utils/store_localized.dart';
import '../../../widgets/app_search_bar.dart';
import '../../../widgets/connection_error_widget.dart';
import 'store_form_screen.dart';

class StoresListScreen extends StatefulWidget {
  const StoresListScreen({super.key});

  @override
  State<StoresListScreen> createState() => _StoresListScreenState();
}

class _StoresListScreenState extends State<StoresListScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<Store> _stores = [];
  bool _loading = true;
  String? _error;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _loadStores();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Store> get _filteredStores {
    final q = _searchController.text.trim().toLowerCase();
    final list = q.isEmpty
        ? List<Store>.from(_stores)
        : _stores.where((s) =>
              s.name.toLowerCase().contains(q) ||
              (s.nameAr?.toLowerCase().contains(q) ?? false) ||
              (s.location?.toLowerCase().contains(q) ?? false) ||
              (s.description?.toLowerCase().contains(q) ?? false)).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<void> _loadStores() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _apiService.get('/stores');
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _stores = (res['data'] as List)
              .map((e) => Store.fromJson(Map<String, dynamic>.from(e)))
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

  void _showStoreDetails(Store store) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: const Icon(Icons.store, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    store.displayName(context),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (store.location != null && store.location!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l10n.location, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(store.location!, style: const TextStyle(fontSize: 16))),
                  IconButton(
                    tooltip: l10n.locationOnMaps,
                    icon: Icon(Icons.map_outlined, color: Theme.of(context).colorScheme.primary),
                    onPressed: () async {
                      final ok = await openGoogleMapsForLocation(store.location!);
                      if (!context.mounted) return;
                      if (!ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.mapsOpenFailed)),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
            if (store.description != null && store.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l10n.description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(store.description!, style: const TextStyle(fontSize: 16)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _deleteStore(Store store) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteStore),
        content: Text(AppLocalizations.of(context)!.confirmDeleteItem(store.displayName(context))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context)!.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: Text(AppLocalizations.of(context)!.delete)),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _apiService.delete('/stores/${store.id}');
      if (mounted) _loadStores();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppSearchBar(
          title: AppLocalizations.of(context)!.storesManagement,
          searchHint: AppLocalizations.of(context)!.searchStoresHint,
          searchController: _searchController,
          showSearch: _showSearch,
        ),
        actions: [
          AppSearchBar.searchButton(context: context, showSearch: _showSearch, onToggleSearch: () {
            setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) _searchController.clear();
            });
          }),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadStores,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const StoreFormScreen()),
          );
          if (added == true && mounted) _loadStores();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _stores.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _stores.isEmpty) {
      return ConnectionErrorWidget(message: _error!, onRetry: _loadStores);
    }
    if (_stores.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noStoresTapAdd));
    }
    final items = _filteredStores;
    if (items.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noStoresMatch));
    }
    return RefreshIndicator(
      onRefresh: _loadStores,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final store = items[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange,
                child: const Icon(Icons.store, color: Colors.white),
              ),
              title: Text(
                store.displayName(context),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (store.location != null && store.location!.isNotEmpty)
                    Row(
                      children: [
                        Expanded(child: Text(store.location!)),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          tooltip: AppLocalizations.of(context)!.locationOnMaps,
                          icon: Icon(Icons.map_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
                          onPressed: () async {
                            final ok = await openGoogleMapsForLocation(store.location!);
                            if (!mounted) return;
                            if (!ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(AppLocalizations.of(context)!.mapsOpenFailed)),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  if (store.description != null &&
                      store.description!.isNotEmpty)
                    Text(
                      store.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'display') {
                    _showStoreDetails(store);
                  } else if (value == 'edit') {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StoreFormScreen(store: store),
                      ),
                    );
                    if (updated == true && mounted) _loadStores();
                  } else if (value == 'delete') {
                    await _deleteStore(store);
                  }
                },
                itemBuilder: (context) {
                  final l10n = AppLocalizations.of(context)!;
                  return [
                    PopupMenuItem(value: 'display', child: Row(children: [const Icon(Icons.visibility), const SizedBox(width: 8), Text(l10n.display)])),
                    PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit), const SizedBox(width: 8), Text(l10n.edit)])),
                    PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete, color: Colors.red), const SizedBox(width: 8), Text(l10n.delete, style: const TextStyle(color: Colors.red))])),
                  ];
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
