import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/product.dart';
import '../../../providers/locale_provider.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/product_localized.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nameArController = TextEditingController();
  final _unitController = TextEditingController();
  final _manufacturerController = TextEditingController();
  final _apiService = ApiService();

  String? _imageUrl;
  List<int>? _imageBytes;
  String? _imageFilename;
  String _status = 'active';
  final List<String> _selectedVariants = [];
  bool _loading = false;
  String? _error;
  bool _appliedArFallback = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final p = widget.product!;
      _nameController.text = p.name;
      _nameArController.text = p.nameAr ?? '';
      _unitController.text = formatRawUnitForDisplay(p.unit);
      _manufacturerController.text = p.manufacturer ?? '';
      _imageUrl = p.image;
      _selectedVariants.clear();
      _selectedVariants.addAll(p.availableColors);
      _status = (p.status.toLowerCase() == 'inactive') ? 'inactive' : 'active';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appliedArFallback) return;
    if (_isEdit && widget.product != null) {
      final isAr = Provider.of<LocaleProvider>(context, listen: false).isArabic;
      final p = widget.product!;
      if (isAr && _nameArController.text.trim().isEmpty) {
        final ar = arabicDisplayNameForProduct(p);
        if (ar.isNotEmpty) {
          _nameArController.text = ar;
        }
      }
    }
    _appliedArFallback = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameArController.dispose();
    _unitController.dispose();
    _manufacturerController.dispose();
    super.dispose();
  }

  Future<void> _showAddOtherVariantDialog(BuildContext context) async {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addOtherVariant),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: l10n.variantNameLabel,
            border: const OutlineInputBorder(),
            hintText: l10n.variantNameHint,
          ),
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.add),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        if (!_selectedVariants.any((s) => s.toLowerCase() == result.toLowerCase())) {
          _selectedVariants.add(result);
        }
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes != null && bytes.isNotEmpty) {
        setState(() {
          _imageBytes = bytes;
          _imageFilename = file.name;
          _imageUrl = null;
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read image data. Try another file.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      String? imageUrl = _imageUrl;
      if (_imageBytes != null && _imageBytes!.isNotEmpty) {
        try {
          final res = await _apiService.uploadImage(
            '/upload/image',
            _imageBytes!,
            _imageFilename ?? 'image.jpg',
          );
          if (res['success'] == true && res['url'] != null) {
            imageUrl = res['url'];
          }
        } catch (uploadErr) {
          if (_isEdit && _imageUrl != null) {
            imageUrl = _imageUrl;
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _isEdit
                      ? AppLocalizations.of(context)!.imageUploadFailedSavingExisting
                      : AppLocalizations.of(context)!.imageUploadFailedSavingNo,
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
      final nameArTrim = _nameArController.text.trim();
      final data = {
        'name': _nameController.text.trim(),
        if (nameArTrim.isNotEmpty) 'nameAr': nameArTrim,
        if (nameArTrim.isNotEmpty) 'name_ar': nameArTrim,
        'image': imageUrl,
        'category': <String>[],
        'categories': <String>[],
        'unit': normalizeUnitForApi(_unitController.text),
        'manufacturer': _manufacturerController.text.trim().isEmpty
            ? null
            : _manufacturerController.text.trim(),
        'status': _status,
        'availableColors': _selectedVariants,
        'stores': _isEdit && widget.product!.stores != null
            ? widget.product!.stores!
                .map((s) => {'store': s.store, 'quantity': s.quantity})
                .toList()
            : [],
      };
      if (_isEdit) {
        if (nameArTrim.isEmpty) {
          data['nameAr'] = null;
          data['name_ar'] = null;
        }
        data['category_ar'] = null;
        data['categoryAr'] = null;
        final res = await _apiService.put('/products/${widget.product!.id}', data);
        if (res['success'] == true && context.mounted) {
          Navigator.pop(context, true);
        } else {
          setState(() => _loading = false);
        }
      } else {
        final res = await _apiService.post('/products', data);
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
    final isAr = context.watch<LocaleProvider>().isArabic;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.editProduct : l10n.addProduct),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isAr) ...[
                TextFormField(
                  controller: _nameArController,
                  decoration: InputDecoration(
                    labelText: l10n.nameRequired,
                    border: const OutlineInputBorder(),
                  ),
                  textDirection: TextDirection.rtl,
                  validator: (v) => v == null || v.trim().isEmpty ? l10n.required : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.nameEnglishRequired,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? l10n.required : null,
                ),
              ] else ...[
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.nameRequired,
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
                  textDirection: TextDirection.rtl,
                ),
              ],
              const SizedBox(height: 16),
              Text(
                l10n.productImageSection,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickImage,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.textTertiary.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: _imageBytes != null || _imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          child: _imageBytes != null
                              ? Image.memory(
                                  Uint8List.fromList(_imageBytes!),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                )
                              : _imageUrl != null
                                  ? Image.network(
                                      _imageUrl!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      errorBuilder: (_, __, ___) => _buildImagePlaceholder(context),
                                    )
                                  : _buildImagePlaceholder(context),
                        )
                      : _buildImagePlaceholder(context),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.folder_open),
                label: Text(l10n.browseImage),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _unitController,
                decoration: InputDecoration(
                  labelText: l10n.unitRequired,
                  border: const OutlineInputBorder(),
                  hintText: l10n.unitHint,
                ),
                validator: (v) => v == null || v.trim().isEmpty ? l10n.required : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _manufacturerController,
                decoration: InputDecoration(
                  labelText: l10n.manufacturer,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.textTertiary.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          l10n.productVariantsTitle,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonal(
                          onPressed: () => _showAddOtherVariantDialog(context),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add, size: 18),
                              const SizedBox(width: 8),
                              Text(l10n.addVariants),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: Text(l10n.other),
                          selected: false,
                          onSelected: (_) => _showAddOtherVariantDialog(context),
                        ),
                        ..._selectedVariants.map(
                          (v) => FilterChip(
                            label: Text(v),
                            selected: true,
                            onSelected: (selected) {
                              if (!selected) {
                                setState(() => _selectedVariants.removeWhere((s) => s == v));
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: InputDecoration(
                  labelText: l10n.status,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 'active', child: Text(l10n.active)),
                  DropdownMenuItem(value: 'inactive', child: Text(l10n.inactive)),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'active'),
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

  Widget _buildImagePlaceholder(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            l10n.tapToSelectImage,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
