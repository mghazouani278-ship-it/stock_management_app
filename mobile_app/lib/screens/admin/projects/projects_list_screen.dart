import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/user.dart';
import '../../../providers/locale_provider.dart';
import '../../../services/api_service.dart';
import '../../../widgets/app_search_bar.dart';
import '../../../widgets/connection_error_widget.dart';
import '../../../widgets/count_badge.dart';
import '../../../utils/l10n_formatters.dart';
import '../../../utils/product_localized.dart';
import '../../../utils/project_localized.dart';
import '../../../utils/project_report_pdf.dart';
import 'project_form_screen.dart';

class ProjectsListScreen extends StatefulWidget {
  const ProjectsListScreen({super.key});

  @override
  State<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends State<ProjectsListScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<Project> _projects = [];
  bool _loading = true;
  String? _error;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Project> _filteredProjects(BuildContext context) {
    final q = _searchController.text.trim().toLowerCase();
    final list = q.isEmpty
        ? List<Project>.from(_projects)
        : _projects.where((p) => projectMatchesSearchQuery(p, q, context)).toList();
    final isAr = Provider.of<LocaleProvider>(context, listen: false).isArabic;
    list.sort((a, b) {
      if (isAr) {
        return arabicDisplayNameForProject(a).compareTo(arabicDisplayNameForProject(b));
      }
      return englishDisplayNameForProject(a).toLowerCase().compareTo(englishDisplayNameForProject(b).toLowerCase());
    });
    return list;
  }

  String _statusLabel(BuildContext context, String status) {
    final l10n = AppLocalizations.of(context)!;
    final s = status.toLowerCase();
    if (s == 'active') return l10n.active;
    if (s == 'inactive') return l10n.inactive;
    return status.toUpperCase();
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

  void _showProjectDetails(Project project) {
    final l10n = AppLocalizations.of(context)!;
    final name = project.displayName(context);
    final desc = project.displayDescription(context);
    final owner = project.displayOwner(context);
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
                name,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(_statusLabel(context, project.status), style: const TextStyle(fontSize: 12)),
                backgroundColor: project.status == 'active' ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
              ),
              if (desc != null && desc.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
              ],
              if (owner != null && owner.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.owner, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(owner, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
              ],
              if (project.users != null && project.users!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.usersAssigned, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
              ],
              if (project.products != null && project.products!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.products, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  l10n.projectQuantitiesNotStockHint,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: project.products!.map((p) {
                    final requested = p.requestedQuantity; // Quantité initiale demandée
                    final supplementary = p.supplementaryQuantity;
                    // Use raw distributed for supplementary overflow, but keep displayed distributed capped at requested.
                    final distRaw = p.distributedQuantity;
                    final distQty = distRaw >= requested ? requested : distRaw;
                    final supplementaryFromDistribution = distRaw > requested ? (distRaw - requested) : 0;
                    // If extra has already been physically distributed, show that real extra amount.
                    // Otherwise fallback to supplementary counter once BOQ requested is fully distributed.
                    final supplementaryDisplay = supplementaryFromDistribution > 0
                        ? supplementaryFromDistribution
                        : (distQty >= requested ? supplementary : 0);
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
                                      _buildQuantityChip(context, l10n.requestedBoq, requested, Colors.blue),
                                      _buildQuantityChip(context, l10n.distributed, distQty, Colors.green),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  _buildQuantityChip(context, l10n.supplementary, supplementaryDisplay, Colors.orange),
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

  String _formatProductWithVariant(BuildContext context, ProjectProduct p) {
    final raw = p.productName ?? p.product;
    final name = raw.trim().isNotEmpty ? localizedApiProductName(context, raw) : raw;
    if (p.color != null && p.color!.isNotEmpty) {
      return '$name (${localizedVariantOrColorLabel(context, p.color!)})';
    }
    return name;
  }

  Widget _buildQuantityChip(BuildContext context, String label, int value, Color color) {
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

  Future<void> _deleteProject(Project project) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteProject),
        content: Text(l10n.confirmDeleteProject(project.displayName(context))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: Text(l10n.delete)),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _apiService.delete('/projects/${project.id}');
      if (mounted) _loadProjects();
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

  Future<void> _showProjectPdfExportOptions(Map<String, dynamic> projectData) async {
    final project = Project.fromJson(Map<String, dynamic>.from(projectData));
    final createdStr = project.createdAt == null
        ? '—'
        : L10nFormatters.formatDateTime(context, project.createdAt!.toLocal());
    final history = project.history ?? const <ProjectHistory>[];
    final updates = <Map<String, dynamic>>[];
    for (int i = 0; i < history.length; i++) {
      final h = history[i];
      if (h.action.toLowerCase() == 'updated' && h.at != null) {
        updates.add({'index': i, 'at': h.at!});
      }
    }
    updates.sort((a, b) => (a['at'] as DateTime).compareTo(b['at'] as DateTime));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.9;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.picture_as_pdf_outlined),
                    title: const Text('Print full project PDF'),
                    onTap: () {
                      Navigator.pop(ctx);
                      ProjectReportPdf.export(context, projectData, mode: ProjectReportPdf.modeFull);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.date_range_outlined),
                    title: const Text('Print creation date'),
                    subtitle: Text(createdStr),
                    onTap: () {
                      Navigator.pop(ctx);
                      ProjectReportPdf.export(
                        context,
                        projectData,
                        mode: ProjectReportPdf.modeCreationOnly,
                      );
                    },
                  ),
                  for (int i = 0; i < updates.length; i++)
                    ListTile(
                      leading: const Icon(Icons.update_outlined),
                      title: Text('Print project update #${i + 1}'),
                      subtitle: Text(
                        L10nFormatters.formatDateTime(
                          context,
                          (updates[i]['at'] as DateTime).toLocal(),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        ProjectReportPdf.export(
                          context,
                          projectData,
                          mode: ProjectReportPdf.modeLastUpdateOnly,
                          historyIndex: updates[i]['index'] as int,
                        );
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.history_outlined),
                    title: const Text('Print all modifications'),
                    subtitle: const Text('Project history with all changes'),
                    onTap: () {
                      Navigator.pop(ctx);
                      ProjectReportPdf.export(
                        context,
                        projectData,
                        mode: ProjectReportPdf.modeAllModifications,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    return Scaffold(
      appBar: AppBar(
        title: AppSearchBar(
          title: AppLocalizations.of(context)!.projectsManagement,
          searchHint: AppLocalizations.of(context)!.searchProjectsHint,
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
            onPressed: _loading ? null : _loadProjects,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push<dynamic>(
            context,
            MaterialPageRoute(builder: (_) => const ProjectFormScreen()),
          );
          if (!mounted) return;
          if (result is Map && result['reload'] == true) {
            await _loadProjects();
          }
        },
        child: const Icon(Icons.add),
      ),
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
      return Center(child: Text(AppLocalizations.of(context)!.noProjectsTapAdd));
    }
    final l10n = AppLocalizations.of(context)!;
    final items = _filteredProjects(context);
    if (items.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noProjectsMatch));
    }
    return RefreshIndicator(
      onRefresh: _loadProjects,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final project = items[index];
          final title = project.displayName(context);
          final desc = project.displayDescription(context);
          final owner = project.displayOwner(context);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: project.status == 'active'
                    ? Colors.purple
                    : Colors.grey,
                child: const Icon(Icons.folder, color: Colors.white),
              ),
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (desc != null && desc.isNotEmpty)
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  if (owner != null && owner.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${l10n.owner}: $owner',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                  Row(
                    children: [
                      Chip(
                        label: Text(
                          _statusLabel(context, project.status),
                          style: const TextStyle(fontSize: 11),
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'display') {
                    _showProjectDetails(project);
                  } else if (value == 'edit') {
                    final result = await Navigator.push<dynamic>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProjectFormScreen(project: project),
                      ),
                    );
                    if (!mounted) return;
                    if (result is Map && result['reload'] == true) {
                      await _loadProjects();
                    }
                  } else if (value == 'delete') {
                    await _deleteProject(project);
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
