import 'package:flutter/material.dart';

import '../../../domain/models/achievement.dart';
import '../../../theme/app_colors.dart';

IconData achievementIcon(AchievementGlyph glyph) => switch (glyph) {
      AchievementGlyph.spark => Icons.auto_awesome_rounded,
      AchievementGlyph.play => Icons.play_circle_outline_rounded,
      AchievementGlyph.gauge => Icons.speed_rounded,
      AchievementGlyph.bolt => Icons.bolt_rounded,
      AchievementGlyph.lightning => Icons.flash_on_rounded,
      AchievementGlyph.book => Icons.menu_book_rounded,
      AchievementGlyph.library => Icons.collections_bookmark_rounded,
      AchievementGlyph.mountain => Icons.landscape_rounded,
      AchievementGlyph.flame => Icons.local_fire_department_rounded,
      AchievementGlyph.crown => Icons.workspace_premium_rounded,
      AchievementGlyph.clock => Icons.hourglass_bottom_rounded,
    };

/// Circular emblem for an achievement, muted when locked.
class AchievementBadge extends StatelessWidget {
  const AchievementBadge({required this.definition, required this.unlocked, this.size = 56, super.key});

  final AchievementDefinition definition;
  final bool unlocked;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: unlocked ? c.accentGradient : null,
        color: unlocked ? null : c.surface,
        boxShadow: unlocked
            ? [BoxShadow(color: c.accent.withValues(alpha: 0.35), blurRadius: size * 0.4, offset: Offset(0, size * 0.1))]
            : null,
      ),
      child: Icon(
        unlocked ? achievementIcon(definition.glyph) : Icons.lock_outline_rounded,
        size: size * 0.46,
        color: unlocked ? c.onAccent : c.subtle,
      ),
    );
  }
}

/// Scale-and-fade entrance used when an achievement is unlocked.
class UnlockReveal extends StatelessWidget {
  const UnlockReveal({required this.child, this.delay = Duration.zero, super.key});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) return child;
    return FutureBuilder<void>(
      future: Future<void>.delayed(delay),
      builder: (context, snapshot) {
        final ready = snapshot.connectionState == ConnectionState.done;
        return AnimatedOpacity(
          opacity: ready ? 1 : 0,
          duration: const Duration(milliseconds: 420),
          child: AnimatedScale(
            scale: ready ? 1 : 0.82,
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutBack,
            child: child,
          ),
        );
      },
    );
  }
}
