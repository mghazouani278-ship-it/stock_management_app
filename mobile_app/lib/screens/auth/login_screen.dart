import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_home_screen.dart';
import '../user/user_home_screen.dart';
import '../warehouse/warehouse_home_screen.dart';

/// Connexion avec le design système [AppTheme] (titres, champs, espacements).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _connectionError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _connectionError = null);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      final role = authProvider.user?.role ?? 'user';
      if (role == 'admin') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
        );
      } else if (role == 'warehouse_user') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WarehouseHomeScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const UserHomeScreen()),
        );
      }
    } else if (mounted) {
      final err = authProvider.error ?? 'Login failed';
      final isConnectionError =
          err.contains('Impossible de joindre') || err.contains('start.bat');
      setState(() => _connectionError = isConnectionError ? err : null);
      if (!isConnectionError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          ),
        );
      }
    }
  }

  void _retryLogin() {
    setState(() => _connectionError = null);
    _handleLogin();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;

    return Theme(
      data: AppTheme.themeForLocale(locale),
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceLg,
              vertical: AppTheme.spaceMd,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: const BoxDecoration(
                        color: AppTheme.logoBackground,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.inventory_2_rounded,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  Text(
                    'Egypt Grid',
                    textAlign: TextAlign.center,
                    style: AppTheme.appTextStyle(
                      context,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.signInToContinue,
                    textAlign: TextAlign.center,
                    style: AppTheme.appTextStyle(
                      context,
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceLg),
                  if (_connectionError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spaceMd),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                            color: AppTheme.error.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _connectionError!,
                            style: AppTheme.appTextStyle(context,
                                fontSize: 14, color: AppTheme.error),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _retryLogin,
                            icon: const Icon(Icons.refresh, size: 20),
                            label: Text(l10n.retry),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.error,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l10n.email,
                      prefixIcon: const Icon(Icons.email_outlined,
                          color: AppTheme.textSecondary),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return l10n.pleaseEnterEmail;
                      if (!value.contains('@'))
                        return l10n.pleaseEnterValidEmail;
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: l10n.password,
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: AppTheme.textSecondary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppTheme.textSecondary,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return l10n.pleaseEnterPassword;
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, _) {
                      return FilledButton(
                        onPressed: authProvider.isLoading ? null : _handleLogin,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spaceMd),
                          backgroundColor: AppTheme.primary,
                        ),
                        child: authProvider.isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                l10n.signIn,
                                style: AppTheme.appTextStyle(
                                  context,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      );
                    },
                  ),
                  const SizedBox(height: AppTheme.spaceLg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
