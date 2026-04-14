import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../theme/app_theme.dart';

/// Sélecteur EN/AR : un clic ouvre un menu avec EN au-dessus et AR en dessous.
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  static const Color _black = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, _) {
        final isArabic = localeProvider.isArabic;
        return Padding(
          padding: const EdgeInsetsDirectional.only(end: 4),
          child: PopupMenuButton<String>(
            offset: const Offset(0, 40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            color: AppTheme.surface,
            elevation: 4,
            onSelected: (value) {
              if (value == 'en') {
                localeProvider.setEnglish();
              } else {
                localeProvider.setArabic();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'en',
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: _MenuLangRow(
                  label: 'EN',
                  selected: !isArabic,
                ),
              ),
              PopupMenuItem<String>(
                value: 'ar',
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: _MenuLangRow(
                  label: 'AR',
                  selected: isArabic,
                ),
              ),
            ],
            child: Material(
              color: _black,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.language_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isArabic ? 'AR' : 'EN',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuLangRow extends StatelessWidget {
  final String label;
  final bool selected;

  const _MenuLangRow({
    required this.label,
    required this.selected,
  });

  static const Color _black = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.language_outlined,
          size: 16,
          color: selected ? _black : AppTheme.textSecondary,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? _black : AppTheme.textSecondary,
          ),
        ),
        if (selected) ...[
          const SizedBox(width: 8),
          Icon(Icons.check_rounded, size: 18, color: _black),
        ],
      ],
    );
  }
}
