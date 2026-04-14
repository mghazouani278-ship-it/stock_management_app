import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/language_selector.dart';
import '../../widgets/menu_card.dart';
import '../auth/login_screen.dart';
import 'users/users_list_screen.dart';
import 'stores/stores_list_screen.dart';
import 'products/products_list_screen.dart';
import 'projects/projects_list_screen.dart';
import 'stock/stock_list_screen.dart';
import 'distributions/distributions_list_screen.dart';
import 'orders/orders_list_screen.dart';
import 'returns/admin_returns_list_screen.dart';
import 'reports/reports_screen.dart';
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final ApiService _apiService = ApiService();
  int _pendingOrdersCount = 0;
  int _orderNotificationsCount = 0;
  int _pendingReturnsCount = 0;
  int _pendingDistributionsCount = 0;
  int _distributionNotificationsCount = 0;
  int _distributionCompletedCount = 0;
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
        _apiService.get('/order-notifications/count'),
        _apiService.get('/returns', queryParams: {'status': 'pending'}),
        _apiService.get('/distributions', queryParams: {'status': 'pending'}),
        _apiService.get('/distribution-notifications/count'),
        _apiService.get('/distribution-notifications/admin-completed/count'),
        _apiService.get('/stock/notifications-count'),
      ]);
      if (mounted) {
        setState(() {
          _pendingOrdersCount = _parseCount(results[0]);
          _orderNotificationsCount = _parseCount(results[1]);
          _pendingReturnsCount = _parseCount(results[2]);
          _pendingDistributionsCount = _parseCount(results[3]);
          _distributionNotificationsCount = _parseCount(results[4]);
          _distributionCompletedCount = _parseCount(results[5]);
          _stockCount = _parseCount(results[6]);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pendingOrdersCount = 0;
          _orderNotificationsCount = 0;
          _pendingReturnsCount = 0;
          _pendingDistributionsCount = 0;
          _distributionNotificationsCount = 0;
          _distributionCompletedCount = 0;
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
        title: Text(l10n.dashboard, style: AppTheme.appTextStyle(context, fontWeight: FontWeight.w600)),
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
                    l10n.adminDashboard,
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
                crossAxisSpacing: AppTheme.spaceMd,
                mainAxisSpacing: AppTheme.spaceMd,
                childAspectRatio: 0.82,
              ),
              delegate: SliverChildListDelegate([
                _buildMenuCard(context, l10n.users, Icons.groups_rounded, const Color(0xFF6366F1), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersListScreen()))),
                _buildMenuCard(context, l10n.stores, Icons.apartment_rounded, const Color(0xFFF59E0B), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StoresListScreen()))),
                _buildMenuCard(context, l10n.products, Icons.inventory_2_rounded, const Color(0xFF10B981), () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsListScreen())).then((_) {
                    if (mounted) _loadBadgeCounts();
                  });
                }),
                _buildMenuCard(context, l10n.projects, Icons.architecture_rounded, const Color(0xFF8B5CF6), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectsListScreen()))),
                _buildMenuCard(context, l10n.stock, Icons.warehouse_rounded, const Color(0xFF06B6D4), () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const StockListScreen())).then((_) {
                    if (mounted) _loadBadgeCounts();
                  });
                }, badgeCount: _stockCount > 0 ? _stockCount : null),
                _buildMenuCard(context, l10n.orders, Icons.receipt_long_rounded, const Color(0xFF10B981), () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminOrdersListScreen())).then((_) {
                    if (mounted) _loadBadgeCounts();
                  });
                }, badgeCount: (_pendingOrdersCount > 0 || _orderNotificationsCount > 0) ? (_pendingOrdersCount > _orderNotificationsCount ? _pendingOrdersCount : _orderNotificationsCount) : null),
                _buildMenuCard(context, l10n.returns, Icons.replay_rounded, const Color(0xFFF59E0B), () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReturnsListScreen())).then((_) {
                    if (mounted) _loadBadgeCounts();
                  });
                }, badgeCount: _pendingReturnsCount),
                _buildMenuCard(context, l10n.distributions, Icons.local_shipping_rounded, const Color(0xFF6366F1), () async {
                  try {
                    await _apiService.put('/distribution-notifications/read', {});
                    await _apiService.put('/distribution-notifications/admin-completed/read', {});
                  } catch (_) {}
                  if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const DistributionsListScreen(showCreateFab: true))).then((_) {
                    if (mounted) _loadBadgeCounts();
                  });
                }, badgeCount: (_pendingDistributionsCount + _distributionNotificationsCount + _distributionCompletedCount) > 0 ? _pendingDistributionsCount + _distributionNotificationsCount + _distributionCompletedCount : null),
                _buildMenuCard(context, l10n.reports, Icons.analytics_rounded, const Color(0xFFEF4444), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()))),
              ]),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, IconData icon, Color accentColor, VoidCallback onTap, {int? badgeCount}) {
    return MenuCard(title: title, icon: icon, accentColor: accentColor, onTap: onTap, badgeCount: badgeCount, transparent: true);
  }
}
