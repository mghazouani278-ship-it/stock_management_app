import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../../models/user.dart';
import '../../../services/api_service.dart';
import '../../../utils/l10n_ui_helpers.dart';
import '../../../utils/product_localized.dart';
import '../../../utils/project_localized.dart';
import '../../widgets/connection_error_widget.dart';
import '../../widgets/count_badge.dart';

class WarehouseProjectsScreen extends StatefulWidget {
  const WarehouseProjectsScreen({super.key});

  @override
  State<WarehouseProjectsScreen> createState() => _WarehouseProjectsScreenState();
}

class _WarehouseProjectsScreenState extends State<WarehouseProjectsScreen> {
  final ApiService _apiService = ApiService();
  List<Project> _projects = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _apiService.get('/projects');
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _projects = (res['data'] as List)
              .map((e) => Project.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _projects.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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

  String _formatProductWithVariant(BuildContext context, ProjectProduct p) {
    final raw = p.productName ?? p.product;
    final name = raw.trim().isNotEmpty ? localizedApiProductName(context, raw) : raw;
    if (p.color != null && p.color!.isNotEmpty) {
      return '$name (${localizedVariantOrColorLabel(context, p.color!)})';
    }
    return name;
  }

  Widget _buildQuantityChip(String label, int value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color.withOpacity(0.95)),
        ),
        CountBadge(
          count: value,
          backgroundColor: color,
          foregroundColor: Colors.white,
          showShadow: false,
          capAt99: false,
        ),
      ],
    );
  }

  void _showProjectDetails(Project project) {
    final l10n = AppLocalizations.of(context)!;
    final ownerLine = project.displayOwner(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
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
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                project.displayName(context),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(localizedUiStatus(context, project.status), style: const TextStyle(fontSize: 12)),
                backgroundColor: project.status == 'active' ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
              ),
              if (project.description != null && project.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(project.description!, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
              ],
              if (ownerLine != null && ownerLine.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.owner, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(ownerLine, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
              ],
              if (project.products != null && project.products!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.products, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: project.products!.map((p) {
                    final requested = p.requestedQuantity; // Quantité initiale demandée
                    final remaining = p.allowedQuantity; // Quantité restante (décrémentée à chaque validation)
                    final distQty = requested - remaining; // Distribué = demandé - restant
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatProductWithVariant(context, p),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      _buildQuantityChip(l10n.requested, requested, Colors.blue),
                                      _buildQuantityChip(l10n.distributed, distQty, Colors.green),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  _buildQuantityChip(l10n.supplementary, p.supplementaryQuantity, Colors.orange),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
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
        title: Text(AppLocalizations.of(context)!.projectsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadProjects,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _projects.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _projects.isEmpty) {
      return ConnectionErrorWidget(message: _error!, onRetry: _loadProjects);
    }
    if (_projects.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noProjects, textAlign: TextAlign.center));
    }
    return RefreshIndicator(
      onRefresh: _loadProjects,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _projects.length,
        itemBuilder: (context, index) {
          final project = _projects[index];
          final ownerLine = project.displayOwner(context);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'view') _showProjectDetails(project);
                },
                itemBuilder: (context) {
                  final l10n = AppLocalizations.of(context)!;
                  return [
                    PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          const Icon(Icons.visibility),
                          const SizedBox(width: 8),
                          Text(l10n.viewDetails),
                        ],
                      ),
                    ),
                  ];
                },
              ),
              leading: CircleAvatar(
                backgroundColor: project.status == 'active'
                    ? Colors.purple
                    : Colors.grey,
                child: const Icon(Icons.folder, color: Colors.white),
              ),
              title: Text(
                project.displayName(context),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (project.description != null &&
                      project.description!.isNotEmpty)
                    Text(
                      project.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  if (ownerLine != null && ownerLine.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${AppLocalizations.of(context)!.owner}: $ownerLine',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Chip(
                        label: Text(
                          localizedUiStatus(context, project.status),
                          style: const TextStyle(fontSize: 11),
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
