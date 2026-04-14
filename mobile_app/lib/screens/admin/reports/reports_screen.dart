import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_search_bar.dart';
import '../../../widgets/menu_card.dart';
import 'report_detail_screen.dart';
import 'report_type_l10n.dart';

enum ReportType {
  distributions('distributions', Icons.local_shipping_rounded),
  orders('orders', Icons.shopping_cart_rounded),
  returns('returns', Icons.undo_rounded),
  damagedProducts('damaged-products', Icons.warning_amber_rounded),
  stockHistory('stock-history', Icons.history_rounded),
  /// Liste via `/projects` (pas `/reports/...`).
  projects('projects', Icons.folder_special_rounded);

  final String endpoint;
  final IconData icon;
  const ReportType(this.endpoint, this.icon);
}

class ReportsScreen extends StatefulWidget {
  final bool allowDelete;

  const ReportsScreen({super.key, this.allowDelete = true});

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

  List<ReportType> _filteredTypes(AppLocalizations l10n) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return ReportType.values;
    return ReportType.values.where((t) {
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
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final types = _filteredTypes(l10n);
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
                          builder: (_) => ReportDetailScreen(reportType: type, allowDelete: widget.allowDelete),
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
