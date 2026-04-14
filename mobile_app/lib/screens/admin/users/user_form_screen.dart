import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/user.dart';
import '../../../services/api_service.dart';

class UserFormScreen extends StatefulWidget {
  final User? user;

  const UserFormScreen({super.key, this.user});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nameArController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();

  String _role = 'user';
  String? _projectId;
  bool _isActive = true;
  List<Map<String, dynamic>> _projects = [];
  bool _loading = false;
  bool _loadingProjects = true;
  String? _error;

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final u = widget.user!;
      _nameController.text = u.name;
      _nameArController.text = u.nameAr ?? '';
      _emailController.text = u.email;
      _role = u.role;
      _projectId = u.project?.id;
      _isActive = u.isActive;
    }
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    try {
      final res = await _apiService.get('/projects');
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _projects = List<Map<String, dynamic>>.from(res['data']);
          _loadingProjects = false;
        });
      } else {
        setState(() => _loadingProjects = false);
      }
    } catch (e) {
      setState(() {
        _loadingProjects = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameArController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        final res = await _apiService.put('/users/${widget.user!.id}', {
          'name': _nameController.text.trim(),
          'nameAr': _nameArController.text.trim().isEmpty ? null : _nameArController.text.trim(),
          'email': _emailController.text.trim().toLowerCase(),
          'role': _role,
          'projectId': _role == 'user' ? _projectId : null,
          'isActive': _isActive,
        });
        if (res['success'] == true && context.mounted) {
          Navigator.pop(context, true);
        } else {
          setState(() => _loading = false);
        }
      } else {
        final res = await _apiService.post('/auth/register', {
          'name': _nameController.text.trim(),
          'nameAr': _nameArController.text.trim().isEmpty ? null : _nameArController.text.trim(),
          'email': _emailController.text.trim().toLowerCase(),
          'password': _passwordController.text,
          'role': _role,
          'projectId': _role == 'user' ? _projectId : null,
        });
        if (res['success'] == true && context.mounted) {
          Navigator.pop(context, true);
        } else {
          setState(() => _loading = false);
        }
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? l10n.editUser : l10n.addUser)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.nameEnglishRequired,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? l10n.required : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameArController,
                decoration: InputDecoration(
                  labelText: l10n.nameArOptional,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.email,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? l10n.required : null,
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.password,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.length < 6 ? l10n.minimum6Characters : null,
                ),
                const SizedBox(height: 16),
              ],
              DropdownButtonFormField<String>(
                value: _role,
                decoration: InputDecoration(
                  labelText: l10n.role,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 'user', child: Text(l10n.roleUser)),
                  DropdownMenuItem(value: 'admin', child: Text(l10n.roleAdmin)),
                  DropdownMenuItem(value: 'warehouse_user', child: Text(l10n.roleWarehouse)),
                ],
                onChanged: (v) => setState(() {
                  _role = v ?? 'user';
                  if (_role != 'user') _projectId = null;
                }),
              ),
              if (_role == 'user') ...[
                const SizedBox(height: 16),
                _loadingProjects
                    ? const CircularProgressIndicator()
                    : DropdownButtonFormField<String>(
                        value: _projectId,
                        decoration: InputDecoration(
                          labelText: l10n.projectOptional,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(l10n.none),
                          ),
                          ..._projects.map((p) => DropdownMenuItem(
                                value: p['id'] ?? p['_id'],
                                child: Text(p['name'] ?? ''),
                              )),
                        ],
                        onChanged: (v) => setState(() => _projectId = v),
                      ),
              ],
              if (_isEdit) ...[
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text(l10n.active),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
