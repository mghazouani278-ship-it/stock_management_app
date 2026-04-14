import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Pastille type badge (menu, notifications, listes de quantités).
///
/// Par défaut (**compact**) : petites tailles fixes comme à l’origine (menu admin).
/// Avec [expandForLongCounts]: le disque s’agrandit pour les grands nombres (liste Stock).
class CountBadge extends StatelessWidget {
  final num count;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool showShadow;
  /// Si vrai, affiche `99+` au-delà de 99 (badges menu / notifications).
  final bool capAt99;
  /// Si vrai, calcule le diamètre selon le texte (quantités stock élevées).
  /// Si faux (défaut), taille compacte fixe — menus, pastilles sur icônes.
  final bool expandForLongCounts;

  const CountBadge({
    super.key,
    required this.count,
    this.backgroundColor = const Color(0xFFFF3B30),
    this.foregroundColor = Colors.white,
    this.showShadow = true,
    this.capAt99 = true,
    this.expandForLongCounts = false,
  });

  static String _label(num count, {required bool capAt99}) {
    if (capAt99 && count > 99) return '99+';
    if (count == count.roundToDouble()) return '${count.toInt()}';
    return count.toString();
  }

  /// Taille compacte d’origine (icônes menu, notifications).
  static double _compactDiameterForText(String text) {
    if (text.length <= 1) return 22;
    if (text.length <= 2) return 24;
    if (text.length <= 3) return 28;
    if (text.length <= 4) return 32;
    return 36;
  }

  static double _fontSizeCompact(String text, double d) {
    if (text.length <= 1) return d * 0.48;
    if (text.length <= 2) return d * 0.42;
    return d * 0.36;
  }

  static double _fontSizeForLabelExpanded(String text) {
    if (text.length <= 1) return 16;
    if (text.length == 2) return 14;
    if (text.length == 3) return 13;
    return 12;
  }

  static TextStyle _textStyleExpanded(String text, Color foregroundColor) {
    return TextStyle(
      color: foregroundColor,
      fontSize: _fontSizeForLabelExpanded(text),
      fontWeight: FontWeight.w700,
      height: 1.1,
    );
  }

  static double _horizontalPadForLabel(String text) {
    if (text.length <= 1) return 7;
    if (text.length == 2) return 8;
    if (text.length == 3) return 9;
    return 10;
  }

  static double _expandedSideLength(String text, Color foregroundColor) {
    const minSide = 36.0;
    final hPad = _horizontalPadForLabel(text);
    const vPad = 8.0;
    final style = _textStyleExpanded(text, foregroundColor);
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: double.infinity);
    final innerW = tp.width + hPad * 2;
    final innerH = tp.height + vPad * 2;
    final diagonal = math.sqrt(innerW * innerW + innerH * innerH);
    return math.max(minSide, diagonal);
  }

  /// Diamètre du disque (pour [Positioned.width] / [Positioned.height] dans un [Stack]).
  static double diameterFor(
    num count, {
    bool capAt99 = true,
    bool expandForLongCounts = false,
  }) {
    final text = _label(count, capAt99: capAt99);
    if (expandForLongCounts) {
      return _expandedSideLength(text, Colors.white);
    }
    return _compactDiameterForText(text);
  }

  String get _text => _label(count, capAt99: capAt99);

  @override
  Widget build(BuildContext context) {
    final text = _text;
    late final double side;
    late final TextStyle style;

    if (expandForLongCounts) {
      side = _expandedSideLength(text, foregroundColor);
      style = _textStyleExpanded(text, foregroundColor);
    } else {
      side = _compactDiameterForText(text);
      style = TextStyle(
        color: foregroundColor,
        fontSize: _fontSizeCompact(text, side),
        fontWeight: FontWeight.w700,
        height: 1.0,
        leadingDistribution: TextLeadingDistribution.even,
      );
    }

    return SizedBox(
      width: side,
      height: side,
      child: Material(
        color: backgroundColor,
        elevation: showShadow ? 3 : 0,
        shadowColor: backgroundColor.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: Center(
          child: Text(
            text,
            maxLines: 1,
            textAlign: TextAlign.center,
            textScaler: TextScaler.noScaling,
            style: style,
          ),
        ),
      ),
    );
  }
}
