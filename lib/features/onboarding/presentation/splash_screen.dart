import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_card.dart';

/// Shown while auth state resolves and the user's local data opens.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          const AccentGlow(size: 420, opacity: 0.18),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FoveaMark(size: 64),
              const SizedBox(height: 20),
              Text(AppInfo.name, style: context.text.displaySmall),
              const SizedBox(height: 6),
              Text(AppInfo.tagline, style: context.text.bodyMedium),
              const SizedBox(height: 40),
              SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The brand mark: a focal point inside a soft ring.
class FoveaMark extends StatelessWidget {
  const FoveaMark({this.size = 48, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c.accent.withValues(alpha: 0.45), width: size * 0.05),
      ),
      alignment: Alignment.center,
      child: Container(
        width: size * 0.34,
        height: size * 0.34,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: c.accentGradient),
      ),
    );
  }
}
