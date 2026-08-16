import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/language_selector.dart';
import '../../widgets/menu_card.dart';
import '../auth/login_screen.dart';
import '../admin/stock/stock_list_screen.dart';
import '../admin/reports/mrp_report_screen.dart';

class FinanceHomeScreen extends StatelessWidget {
  const FinanceHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Finance',
          style: AppTheme.appTextStyle(context, fontWeight: FontWeight.w600),
        ),
        actions: [
          const LanguageSelector(),
          IconButton(
            icon: const Icon(Icons.logout),
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
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: [
          MenuCard(
            title: l10n.stock,
            icon: Icons.inventory_2_outlined,
            accentColor: AppTheme.primary,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const StockListScreen(readOnly: true),
              ),
            ),
          ),
          MenuCard(
            title: l10n.procurementPlanning,
            icon: Icons.analytics_outlined,
            accentColor: Colors.teal,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MrpReportScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
