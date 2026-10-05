import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../theme/app_colors.dart';
import 'pressable.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
    this.gradient,
    this.color,
    this.radius = LayoutConstants.cardRadius,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final Color? color;
  final double radius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? c.card) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: c.border.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return Pressable(onTap: onTap, semanticLabel: semanticLabel, child: card);
  }
}

/// A soft glow used behind hero content. Sparse use only.
class AccentGlow extends StatelessWidget {
  const AccentGlow({this.size = 280, this.opacity = 0.22, this.color, super.key});

  final double size;
  final double opacity;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final base = color ?? context.colors.accent;
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [base.withValues(alpha: opacity), base.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
