import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/language_selector.dart';
import '../../widgets/menu_card.dart';
import '../auth/login_screen.dart';
import 'warehouse_stock_screen.dart';
import 'warehouse_projects_screen.dart';
import 'warehouse_distribution_form_screen.dart';
import 'warehouse_stock_summary_screen.dart';
import 'warehouse_approved_orders_screen.dart';
import 'warehouse_damaged_products_screen.dart';
import 'warehouse_returns_screen.dart';
import '../admin/distributions/distributions_list_screen.dart';
import '../admin/reports/reports_screen.dart';

class WarehouseHomeScreen extends StatefulWidget {
  const WarehouseHomeScreen({super.key});

  @override
  State<WarehouseHomeScreen> createState() => _WarehouseHomeScreenState();
}

class _WarehouseHomeScreenState extends State<WarehouseHomeScreen> {
  final ApiService _apiService = ApiService();
  int _pendingOrdersCount = 0;
  int _approvedOrdersCount = 0;
  int _pendingReturnsCount = 0;
  int _pendingDistributionsCount = 0;
  int _damagedProductsCount = 0;
  int _stockCount = 0;

  @override
  void initState() {
    super.initState();
    _loadBadgeCounts();
  }

  Future<void> _loadBadgeCounts() async {
    try {
      final results = await Future.wait([
        _apiService.get('/orders', queryParams: {'status': 'pending'}),
        _apiService.get('/order-notifications'),
        _apiService.get('/returns', queryParams: {'status': 'pending'}),
        _apiService.get('/distributions', queryParams: {'status': 'pending'}),
        _apiService.get('/damaged-products', queryParams: {'status': 'pending'}),
      ]);
      if (mounted) {
        final orderNotifs = results[1] is Map && results[1]['data'] is List
            ? (results[1]['data'] as List).where((n) => n['type'] == 'order_approved').length
            : 0;
        setState(() {
          _pendingOrdersCount = _parseCount(results[0]);
          _approvedOrdersCount = orderNotifs;
          _pendingReturnsCount = _parseCount(results[2]);
          _pendingDistributionsCount = _parseCount(results[3]);
          _damagedProductsCount = _parseCount(results[4]);
          _stockCount = 0;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pendingOrdersCount = 0;
          _approvedOrdersCount = 0;
          _pendingReturnsCount = 0;
          _pendingDistributionsCount = 0;
          _damagedProductsCount = 0;
          _stockCount = 0;
        });
      }
    }
  }

  int _parseCount(dynamic res) {
    if (res is! Map || res['success'] != true) return 0;
    final c = res['count'];
    if (c != null) {
      if (c is int) return c;
      final parsed = int.tryParse(c.toString());
      if (parsed != null) return parsed;
    }
    final data = res['data'];
    if (data is List) return data.length;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(l10n.warehouse, style: AppTheme.appTextStyle(context, fontWeight: FontWeight.w600)),
        actions: [
          const LanguageSelector(),
          IconButton(
            icon: Image.asset(
              'assets/images/logout.png',
              width: 25,
              height: 25,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.logout_rounded, size: 25),
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: null,
              overlayColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
              padding: const EdgeInsets.all(10),
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadBadgeCounts,
        color: AppTheme.primary,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.spaceMd, AppTheme.spaceMd, AppTheme.spaceMd, AppTheme.spaceSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.welcomeBack,
                    style: AppTheme.appTextStyle(context, 
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.warehouseDashboard,
                    style: AppTheme.appTextStyle(context, 
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: AppTheme.spaceSm,
                mainAxisSpacing: AppTheme.spaceSm,
                childAspectRatio: 0.92,
              ),
              delegate: SliverChildListDelegate([
                _buildMenuCard(context, l10n.stock, Icons.warehouse_rounded, const Color(0xFF10B981), () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehouseStockScreen())).then((_) {
                    if (mounted) _loadBadgeCounts();
                  });
                }, badgeCount: _stockCount > 0 ? _stockCount : null),
                _buildMenuCard(context, l10n.projects, Icons.architecture_rounded, const Color(0xFF8B5CF6), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehouseProjectsScreen()))),
                _buildMenuCard(context, l10n.orders, Icons.local_shipping_rounded, const Color(0xFF6366F1), () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehouseApprovedOrdersScreen())).then((_) {
                    if (mounted) _loadBadgeCounts();
                  });
                }, badgeCount: _approvedOrdersCount > 0 ? _approvedOrdersCount : null),
                _buildMenuCard(context, l10n.myDistributions, Icons.fact_check_rounded, const Color(0xFFF59E0B), () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DistributionsListScreen(showCreateFab: true, allowDelete: false))).then((_) {
                    if (mounted) _loadBadgeCounts();
                  });
                }, badgeCount: _pendingDistributionsCount),
                _buildMenuCard(context, l10n.totalStock, Icons.stacked_bar_chart_rounded, const Color(0xFFEF4444), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehouseStockSummaryScreen()))),
                _buildMenuCard(context, l10n.reports, Icons.analytics_rounded, const Color(0xFF64748B), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen(allowDelete: false)))),
                _buildMenuCard(context, l10n.damagedProductsMenu, Icons.warning_amber_rounded, const Color(0xFFEF4444), () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehouseDamagedProductsScreen())).then((_) {
                    if (mounted) _loadBadgeCounts();
                  });
                }, badgeCount: _damagedProductsCount > 0 ? _damagedProductsCount : null),
                _buildMenuCard(context, l10n.returns, Icons.undo_rounded, const Color(0xFFF59E0B), () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehouseReturnsScreen())).then((_) {
                    if (mounted) _loadBadgeCounts();
                  });
                }, badgeCount: _pendingReturnsCount),
              ]),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, IconData icon, Color accentColor, VoidCallback onTap, {int? badgeCount}) {
    return MenuCard(
      title: title,
      icon: icon,
      accentColor: accentColor,
      onTap: onTap,
      badgeCount: badgeCount,
      transparent: true,
    );
  }
}
