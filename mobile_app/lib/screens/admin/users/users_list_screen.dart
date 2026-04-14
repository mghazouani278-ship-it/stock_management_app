import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/user.dart';
import '../../../providers/locale_provider.dart';
import '../../../services/api_service.dart';
import '../../../utils/l10n_ui_helpers.dart';
import '../../../utils/project_localized.dart';
import '../../../widgets/connection_error_widget.dart';
import '../../../widgets/app_search_bar.dart';
import 'user_form_screen.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<User> _users = [];
  bool _loading = true;
  String? _error;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<User> _filteredUsers(BuildContext context) {
    final q = _searchController.text.trim().toLowerCase();
    final list = q.isEmpty
        ? List<User>.from(_users)
        : _users.where((u) {
            if (u.name.toLowerCase().contains(q) ||
                (u.nameAr?.toLowerCase().contains(q) ?? false) ||
                u.email.toLowerCase().contains(q) ||
                u.role.toLowerCase().contains(q) ||
                (u.project?.name.toLowerCase().contains(q) ?? false) ||
                (u.project?.nameAr?.toLowerCase().contains(q) ?? false)) {
              return true;
            }
            if (localizedUserRole(context, u.role).toLowerCase().contains(q)) {
              return true;
            }
            if (localizedDisplayUserName(context, u.name, nameAr: u.nameAr).toLowerCase().contains(q)) {
              return true;
            }
            return false;
          }).toList();
    list.sort((a, b) => localizedDisplayUserName(context, a.name, nameAr: a.nameAr).toLowerCase().compareTo(
          localizedDisplayUserName(context, b.name, nameAr: b.nameAr).toLowerCase(),
        ));
    return list;
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _apiService.get('/users');
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _users = (res['data'] as List)
              .map((e) => User.fromJson(Map<String, dynamic>.from(e)))
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

  Future<void> _deleteUser(User user) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteUser),
        content: Text(l10n.confirmDeleteItem(localizedDisplayUserName(context, user.name, nameAr: user.nameAr))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _apiService.delete('/users/${user.id}');
      if (mounted) _loadUsers();
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

  Future<void> _toggleActive(User user) async {
    try {
      await _apiService.put('/users/${user.id}/activate', {
        'isActive': !user.isActive,
      });
      if (mounted) _loadUsers();
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
    context.watch<LocaleProvider>();
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: AppSearchBar(
          title: l10n.usersManagement,
          searchHint: l10n.searchUsersHint,
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
            onPressed: _loading ? null : _loadUsers,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const UserFormScreen()),
          );
          if (added == true && mounted) _loadUsers();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _users.isEmpty) {
      return ConnectionErrorWidget(message: _error!, onRetry: _loadUsers);
    }
    if (_users.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context)!.noUsersTapAdd),
      );
    }
    final items = _filteredUsers(context);
    if (items.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context)!.noUsersMatch),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final user = items[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: user.isActive ? Colors.green : Colors.grey,
                child: Text(
                  localizedUserAvatarLetter(context, user.name, nameAr: user.nameAr),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                localizedDisplayUserName(context, user.name, nameAr: user.nameAr),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: user.isActive ? null : Colors.grey,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.email),
                  Row(
                    children: [
                      Chip(
                        label: Text(
                          localizedUserRole(context, user.role),
                          style: const TextStyle(fontSize: 11),
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      if (user.project != null) ...[
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            user.project!.displayName(context),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserFormScreen(user: user),
                      ),
                    );
                    if (updated == true && mounted) _loadUsers();
                  } else if (value == 'toggle') {
                    await _toggleActive(user);
                  } else if (value == 'delete') {
                    await _deleteUser(user);
                  }
                },
                itemBuilder: (context) {
                  final l10n = AppLocalizations.of(context)!;
                  return [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit),
                          const SizedBox(width: 8),
                          Text(l10n.edit),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(user.isActive ? Icons.block : Icons.check_circle),
                          const SizedBox(width: 8),
                          Text(user.isActive ? l10n.deactivate : l10n.activate),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(l10n.delete, style: const TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
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
