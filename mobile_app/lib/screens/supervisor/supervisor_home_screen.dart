import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../utils/l10n_ui_helpers.dart';
import '../../widgets/language_selector.dart';
import '../../widgets/menu_card.dart';
import '../auth/login_screen.dart';
import '../admin/orders/orders_list_screen.dart';
import '../admin/projects/projects_list_screen.dart';
import '../admin/users/users_list_screen.dart';
import '../admin/returns/admin_returns_list_screen.dart';
import '../admin/reports/reports_screen.dart';
import '../user/damaged_products/damaged_products_list_screen.dart';

class SupervisorHomeScreen extends StatefulWidget {
  const SupervisorHomeScreen({super.key});

  @override
  State<SupervisorHomeScreen> createState() => _SupervisorHomeScreenState();
}

class _SupervisorHomeScreenState extends State<SupervisorHomeScreen> with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  int _pendingOrdersCount = 0;
  int _orderNotificationsCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBadgeCounts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadBadgeCounts();
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

  Future<void> _loadBadgeCounts() async {
    try {
      final results = await Future.wait([
        _apiService.get('/orders/count', queryParams: {'status': 'pending'}),
        _apiService.get('/order-notifications/count'),
      ]);
      if (!mounted) return;
      setState(() {
        _pendingOrdersCount = _parseCount(results[0]);
        _orderNotificationsCount = _parseCount(results[1]);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pendingOrdersCount = 0;
        _orderNotificationsCount = 0;
      });
    }
  }

  int? get _ordersBadge {
    final n = _pendingOrdersCount > _orderNotificationsCount
        ? _pendingOrdersCount
        : _orderNotificationsCount;
    return n > 0 ? n : null;
  }

  Future<void> _openOrders() async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminOrdersListScreen()),
    );
    if (mounted) _loadBadgeCounts();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final userName = user != null
        ? localizedDisplayUserName(context, user.name, nameAr: user.nameAr)
        : '';
    final userEmail = user?.email.trim() ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: const SizedBox.shrink(),
        title: Image.asset(
          'assets/images/logo1.png',
          height: 100,
          width: 100,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/images/logo.png',
            height: 100,
            width: 100,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.grid_on, size: 64, color: AppTheme.logoBackground),
          ),
        ),
        centerTitle: true,
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
              overlayColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
              padding: const EdgeInsets.all(10),
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadBadgeCounts,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (user != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Image.asset(
                          'assets/images/images1.jpg',
                          width: double.infinity,
                          height: 160,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 160,
                            color: AppTheme.primary.withOpacity(0.1),
                          ),
                        ),
                        Container(
                          height: 160,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.4),
                                Colors.black.withOpacity(0.8),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.dashboard,
                                style: AppTheme.appTextStyle(
                                  context,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                userName,
                                style: AppTheme.appTextStyle(
                                  context,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              if (userEmail.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  userEmail,
                                  style: AppTheme.appTextStyle(
                                    context,
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppTheme.spaceMd, AppTheme.spaceSm, AppTheme.spaceMd, AppTheme.spaceSm),
                child: Text(
                  l10n.dashboard,
                  style: AppTheme.appTextStyle(
                    context,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    SizedBox(
                      height: 140,
                      child: Row(
                        children: [
                          Expanded(
                            child: MenuCard(
                              title: l10n.orders,
                              icon: Icons.receipt_long_rounded,
                              accentColor: const Color(0xFF6366F1),
                              onTap: _openOrders,
                              badgeCount: _ordersBadge,
                              transparent: true,
                              titleFontSize: 14,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spaceMd),
                          Expanded(
                            child: MenuCard(
                              title: l10n.users,
                              icon: Icons.people_outline,
                              accentColor: Colors.indigo,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const UsersListScreen()),
                              ),
                              transparent: true,
                              titleFontSize: 14,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spaceMd),
                          Expanded(
                            child: MenuCard(
                              title: l10n.projects,
                              icon: Icons.folder_outlined,
                              accentColor: Colors.teal,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ProjectsListScreen()),
                              ),
                              transparent: true,
                              titleFontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    SizedBox(
                      height: 140,
                      child: Row(
                        children: [
                          Expanded(
                            child: MenuCard(
                              title: l10n.returns,
                              icon: Icons.replay_rounded,
                              accentColor: const Color(0xFFF59E0B),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AdminReturnsListScreen()),
                              ).then((_) {
                                if (mounted) _loadBadgeCounts();
                              }),
                              transparent: true,
                              titleFontSize: 14,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spaceMd),
                          Expanded(
                            child: MenuCard(
                              title: l10n.damages,
                              icon: Icons.warning_amber_rounded,
                              accentColor: const Color(0xFFEF4444),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const DamagedProductsListScreen()),
                              ),
                              transparent: true,
                              titleFontSize: 14,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spaceMd),
                          Expanded(
                            child: MenuCard(
                              title: l10n.reports,
                              icon: Icons.analytics_rounded,
                              accentColor: const Color(0xFF0EA5E9),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ReportsScreen(allowDelete: false),
                                ),
                              ),
                              transparent: true,
                              titleFontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
