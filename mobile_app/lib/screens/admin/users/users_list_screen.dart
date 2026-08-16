import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/user.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../services/api_service.dart';
import '../../../utils/l10n_ui_helpers.dart';
import '../../../utils/project_localized.dart';
import '../../../utils/roles.dart';
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
      final role = Provider.of<AuthProvider>(context, listen: false).user?.role;
      final path = (role == 'supervisor') ? '/users/for-supervisor' : '/users';
      final res = await _apiService.get(path);
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

  Future<void> _showUserDetails(User user) async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        maxChildSize: 0.85,
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
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                localizedDisplayUserName(context, user.name, nameAr: user.nameAr),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(localizedUserRole(context, user.role), style: const TextStyle(fontSize: 12)),
                backgroundColor: user.isActive
                    ? Colors.green.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2),
              ),
              const SizedBox(height: 16),
              Text(l10n.email, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(user.email, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
              if (user.project != null) ...[
                const SizedBox(height: 16),
                Text(l10n.projects, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  user.project!.displayName(context),
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
              const SizedBox(height: 16),
              Text(l10n.status, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                user.isActive ? l10n.active : l10n.inactive,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    final l10n = AppLocalizations.of(context)!;
    final canManageUsers = !isSupervisor(context.watch<AuthProvider>().user?.role);
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
      body: _buildBody(canManageUsers: canManageUsers),
      floatingActionButton: canManageUsers
          ? FloatingActionButton(
              onPressed: () async {
                final added = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const UserFormScreen()),
                );
                if (added == true && mounted) _loadUsers();
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildBody({required bool canManageUsers}) {
    if (_loading && _users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _users.isEmpty) {
      return ConnectionErrorWidget(message: _error!, onRetry: _loadUsers);
    }
    if (_users.isEmpty) {
      return Center(
        child: Text(
          canManageUsers
              ? AppLocalizations.of(context)!.noUsersTapAdd
              : AppLocalizations.of(context)!.noUsersMatch,
        ),
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
              onTap: canManageUsers ? null : () => _showUserDetails(user),
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
                  if (value == 'display') {
                    await _showUserDetails(user);
                  } else if (value == 'edit' && canManageUsers) {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserFormScreen(user: user),
                      ),
                    );
                    if (updated == true && mounted) _loadUsers();
                  } else if (value == 'toggle' && canManageUsers) {
                    await _toggleActive(user);
                  } else if (value == 'delete' && canManageUsers) {
                    await _deleteUser(user);
                  }
                },
                itemBuilder: (context) {
                  final l10n = AppLocalizations.of(context)!;
                  return [
                    PopupMenuItem(
                      value: 'display',
                      child: Row(
                        children: [
                          const Icon(Icons.visibility),
                          const SizedBox(width: 8),
                          Text(l10n.display),
                        ],
                      ),
                    ),
                    if (canManageUsers) ...[
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
                    ],
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
