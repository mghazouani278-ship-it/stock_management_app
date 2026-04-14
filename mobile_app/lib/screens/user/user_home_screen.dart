import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../utils/project_localized.dart';
import '../../widgets/language_selector.dart';
import '../../widgets/menu_card.dart';
import '../auth/login_screen.dart';
import 'orders/orders_list_screen.dart';
import 'returns/returns_list_screen.dart';
import 'damaged_products/damaged_products_list_screen.dart';

class UserHomeScreen extends StatelessWidget {
  const UserHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final projectOwnerLine =
        user?.project != null ? user!.project!.displayOwner(context) : null;

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
            errorBuilder: (_, __, ___) => const Icon(Icons.grid_on, size: 64, color: AppTheme.logoBackground),
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
              foregroundColor: null,
              overlayColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
              padding: const EdgeInsets.all(10),
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
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
      body: CustomScrollView(
        slivers: [
          if (user?.project != null)
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
                              l10n.project,
                              style: AppTheme.appTextStyle(context, 
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user!.project!.displayName(context),
                              style: AppTheme.appTextStyle(context, 
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            if (projectOwnerLine != null && projectOwnerLine.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${l10n.owner}: $projectOwnerLine',
                                style: AppTheme.appTextStyle(context, 
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
                style: AppTheme.appTextStyle(context, 
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
              child: ClipRect(
                child: SizedBox(
                  height: 140,
                  child: Row(
                  children: [
                  Expanded(
                    child: MenuCard(
                      title: l10n.orders,
                      icon: Icons.receipt_long_rounded,
                      accentColor: const Color(0xFF6366F1),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersListScreen())),
                      transparent: true,
                      titleFontSize: 14,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: MenuCard(
                      title: l10n.returns,
                      icon: Icons.replay_rounded,
                      accentColor: const Color(0xFFF59E0B),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReturnsListScreen())),
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
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DamagedProductsListScreen())),
                      transparent: true,
                      titleFontSize: 14,
                    ),
                  ),
                ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
