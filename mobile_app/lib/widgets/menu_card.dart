import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'count_badge.dart';

/// 2026 Ultra-modern menu card
/// Glassmorphism, soft gradients, refined neo-morphism, micro-animations
class MenuCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final int? badgeCount;
  final bool transparent;
  final double? titleFontSize;

  const MenuCard({
    super.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.badgeCount,
    this.transparent = false,
    this.titleFontSize,
  });

  @override
  State<MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<MenuCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _glowAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _fadeAnimation = Tween<double>(begin: 1, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            ),
          );
        },
        child: _buildCard(),
      ),
    );
  }

  Widget _buildCard() {
    final isTransparent = widget.transparent;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: EdgeInsets.all(isTransparent ? AppTheme.spaceSm : AppTheme.spaceMd),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            color: isTransparent ? Colors.transparent : null,
            boxShadow: isTransparent ? null : _buildNeoShadow(),
            border: isTransparent
                ? null
                : Border.all(
                    color: Colors.white.withOpacity(0.6),
                    width: 1,
                  ),
          ),
          // Pas de ClipRRect autour du contenu transparent : le badge dépasse (top/right négatifs)
          // et serait tronqué en arc — plus un « cercle » visible.
          child: isTransparent
              ? _buildContent()
              : ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.85),
                            Colors.white.withOpacity(0.65),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      ),
                      child: _buildContent(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  List<BoxShadow> _buildNeoShadow() {
    return [
      BoxShadow(
        color: widget.accentColor.withOpacity(0.08),
        blurRadius: 20,
        offset: const Offset(0, 8),
        spreadRadius: -2,
      ),
      BoxShadow(
        color: const Color(0xFF0F172A).withOpacity(0.04),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: Colors.white.withOpacity(0.9),
        blurRadius: 0,
        offset: const Offset(-1, -1),
        spreadRadius: 0,
      ),
    ];
  }

  Widget _buildContent() {
    final hasBadge = widget.badgeCount != null && widget.badgeCount! > 0;
    final badgeD = hasBadge ? CountBadge.diameterFor(widget.badgeCount!) : 0.0;
    return Padding(
      padding: EdgeInsets.only(top: hasBadge ? 10 : 4, bottom: 4, left: 4, right: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _buildIconContainer(),
              if (hasBadge)
                Positioned(
                  top: -6,
                  right: -6,
                  width: badgeD,
                  height: badgeD,
                  child: CountBadge(count: widget.badgeCount!),
                ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.clip,
              softWrap: true,
              style: AppTheme.appTextStyle(context, 
                fontSize: widget.titleFontSize ?? 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                letterSpacing: -0.2,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconContainer() {
    final transparent = widget.transparent;
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final size = transparent ? 48.0 : 52.0;
        final iconSize = transparent ? 24.0 : 26.0;
        final iconColor = widget.accentColor;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.accentColor.withOpacity(transparent ? 0.18 : 0.2),
                widget.accentColor.withOpacity(transparent ? 0.06 : 0.08),
              ],
            ),
            boxShadow: transparent
                ? [
                    BoxShadow(
                      color: widget.accentColor.withOpacity(0.12 * _glowAnimation.value),
                      blurRadius: 8 * _glowAnimation.value,
                      spreadRadius: 0,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: widget.accentColor.withOpacity(0.25 * _glowAnimation.value),
                      blurRadius: 12 * _glowAnimation.value,
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.8),
                      blurRadius: 0,
                      offset: const Offset(-2, -2),
                    ),
                  ],
          ),
          child: Center(
            child: Icon(
              widget.icon,
              size: iconSize,
              color: iconColor,
            ),
          ),
        );
      },
    );
  }

}

