import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/store.dart';
import '../../../services/api_service.dart';
import '../../../utils/maps_launch.dart';

class StoreFormScreen extends StatefulWidget {
  final Store? store;

  const StoreFormScreen({super.key, this.store});

  @override
  State<StoreFormScreen> createState() => _StoreFormScreenState();
}

class _StoreFormScreenState extends State<StoreFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nameArController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _apiService = ApiService();

  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.store != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final s = widget.store!;
      _nameController.text = s.name;
      _nameArController.text = s.nameAr ?? '';
      _locationController.text = s.location ?? '';
      _descriptionController.text = s.description ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameArController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = {
        'name': _nameController.text.trim(),
        'nameAr': _nameArController.text.trim().isEmpty ? null : _nameArController.text.trim(),
        'location': _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      };
      if (_isEdit) {
        final res = await _apiService.put('/stores/${widget.store!.id}', data);
        if (res['success'] == true && context.mounted) {
          Navigator.pop(context, true);
        } else {
          setState(() => _loading = false);
        }
      } else {
        final res = await _apiService.post('/stores', data);
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

  Future<void> _openMapsFromField() async {
    final l10n = AppLocalizations.of(context)!;
    final q = _locationController.text.trim();
    if (q.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.enterLocationForMaps)),
      );
      return;
    }
    final ok = await openGoogleMapsForLocation(q);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.mapsOpenFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? l10n.editStore : l10n.addStore)),
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
                controller: _locationController,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.location,
                  hintText: l10n.locationMapsHint,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: l10n.locationOnMaps,
                    icon: const Icon(Icons.map_outlined),
                    onPressed: _loading ? null : _openMapsFromField,
                  ),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _loading ? null : _openMapsFromField,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(l10n.locationOnMaps),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.description,
                  border: const OutlineInputBorder(),
                ),
              ),
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
