import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/roles.dart';
import '../../../widgets/app_search_bar.dart';
import '../../../widgets/menu_card.dart';
import 'report_detail_screen.dart';
import 'report_type_l10n.dart';
import 'mrp_report_screen.dart';

enum ReportType {
  distributions('distributions', Icons.move_to_inbox_rounded),
  orders('orders', Icons.shopping_cart_rounded),
  returns('returns', Icons.undo_rounded),
  damagedProducts('damaged-products', Icons.warning_amber_rounded),
  stockHistory('stock-history', Icons.history_rounded),
  /// Liste via `/projects` (pas `/reports/...`).
  projects('projects', Icons.folder_special_rounded),
  /// Procurement Planning — dedicated screen.
  mrp('mrp', Icons.analytics_outlined);

  final String endpoint;
  final IconData icon;
  const ReportType(this.endpoint, this.icon);
}

/// Reports visible for each role.
List<ReportType> reportTypesForRole(String? role) {
  final r = normalizeRole(role);
  if (r == 'finance') {
    return const [ReportType.mrp];
  }
  if (r == 'supervisor') {
    return const [ReportType.distributions];
  }
  if (isWarehouseLike(r)) {
    return const [
      ReportType.mrp,
      ReportType.distributions,
      ReportType.stockHistory,
      ReportType.projects,
    ];
  }
  // admin / manager — all
  return ReportType.values;
}

class ReportsScreen extends StatefulWidget {
  final bool allowDelete;
  /// If set, only these types are shown (overrides role filter).
  final List<ReportType>? onlyTypes;

  const ReportsScreen({super.key, this.allowDelete = true, this.onlyTypes});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ReportType> _allowedTypes(BuildContext context) {
    if (widget.onlyTypes != null) return widget.onlyTypes!;
    final role = Provider.of<AuthProvider>(context, listen: false).user?.role;
    return reportTypesForRole(role);
  }

  List<ReportType> _filteredTypes(BuildContext context, AppLocalizations l10n) {
    final base = _allowedTypes(context);
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return base;
    return base.where((t) {
      final full = t.titleFull(l10n).toLowerCase();
      final menu = t.titleMenu(l10n).toLowerCase().replaceAll('\n', ' ');
      return full.contains(q) || menu.contains(q);
    }).toList();
  }

  static const _reportColors = [
    Color(0xFF6366F1),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF06B6D4),
    Color(0xFF8B5CF6),
    Color(0xFF0EA5E9),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final types = _filteredTypes(context, l10n);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: AppSearchBar(
          title: l10n.reports,
          searchHint: l10n.searchReportsHint,
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
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              child: Text(
                l10n.selectReportType,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ),
          ),
          if (types.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  l10n.noReportTypesMatchSearch,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: AppTheme.spaceMd,
                  mainAxisSpacing: AppTheme.spaceMd,
                  childAspectRatio: 1.1,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= types.length) return const SizedBox.shrink();
                    final type = types[index];
                    final color = _reportColors[index % _reportColors.length];
                    return MenuCard(
                      title: type.titleMenu(l10n),
                      icon: type.icon,
                      accentColor: color,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => type == ReportType.mrp
                              ? const MrpReportScreen()
                              : ReportDetailScreen(reportType: type, allowDelete: widget.allowDelete),
                        ),
                      ),
                      transparent: true,
                    );
                  },
                  childCount: types.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
