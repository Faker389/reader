import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/models/achievement.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/progress.dart';
import '../../home/presentation/main_shell.dart';
import '../../statistics/application/stats_providers.dart';
import 'achievement_badge.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(achievementProgressProvider);
    final unlocked = all.where((a) => a.isUnlocked).toList()
      ..sort((a, b) => b.unlocked!.unlockedAt.compareTo(a.unlocked!.unlockedAt));
    final locked = all.where((a) => !a.isUnlocked).toList()..sort((a, b) => b.fraction.compareTo(a.fraction));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: LayoutConstants.maxContentWidth),
            child: LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth > 560 ? 3 : 2;
              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    sliver: SliverList.list(
                      children: [
                        Text('Achievements', style: context.text.displaySmall),
                        const SizedBox(height: 16),
                        _Summary(unlocked: unlocked.length, total: all.length),
                        const SizedBox(height: 24),
                        if (unlocked.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Text(
                              'Your first achievement is only a few words away.',
                              style: context.text.bodyLarge?.copyWith(color: context.colors.muted),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (unlocked.isNotEmpty) ...[
                    const _Header('Unlocked'),
                    _Grid(items: unlocked, columns: columns),
                  ],
                  if (locked.isNotEmpty) ...[
                    _Header(unlocked.isEmpty ? 'To unlock' : 'Still ahead'),
                    _Grid(items: locked, columns: columns),
                  ],
                  SliverToBoxAdapter(child: SizedBox(height: shellBottomInset(context))),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        sliver: SliverToBoxAdapter(child: Text(title, style: context.text.titleLarge)),
      );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.unlocked, required this.total});

  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      gradient: LinearGradient(
        colors: [c.accent.withValues(alpha: 0.22), c.accentSecondary.withValues(alpha: 0.08), c.card],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        children: [
          ProgressRing(
            value: total == 0 ? 0 : unlocked / total,
            size: 72,
            strokeWidth: 7,
            child: Text('$unlocked', style: context.text.titleLarge),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$unlocked of $total unlocked', style: context.text.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Milestones for words, speed, books and consistency.',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.items, required this.columns});

  final List<AchievementProgress> items;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 196,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) => _AchievementCard(progress: items[i]),
      ),
    );
  }
}

String _progressText(AchievementProgress p) {
  final d = p.definition;
  String fmt(int v) => d.metric == AchievementMetric.totalSeconds
      ? Formatters.duration(Duration(seconds: v))
      : Formatters.compact(v);
  final current = p.current.clamp(0, d.threshold);
  if (d.metric == AchievementMetric.totalSeconds) return '${fmt(current)} / ${fmt(d.threshold)}';
  return '${fmt(current)} / ${fmt(d.threshold)} ${d.unit}';
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.progress});

  final AchievementProgress progress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = progress.definition;
    final unlocked = progress.isUnlocked;
    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: () => _showDetails(context, progress),
      semanticLabel: '${d.title}, ${unlocked ? 'unlocked' : 'locked'}',
      gradient: unlocked
          ? LinearGradient(
              colors: [c.accent.withValues(alpha: 0.18), c.card],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AchievementBadge(definition: d, unlocked: unlocked, size: 48),
          const Spacer(),
          Text(
            d.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleMedium?.copyWith(color: unlocked ? c.text : c.muted),
          ),
          const SizedBox(height: 4),
          Text(d.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
          const SizedBox(height: 12),
          if (unlocked)
            Text(
              'Unlocked ${Formatters.shortDate(progress.unlocked!.unlockedAt)}',
              style: context.text.labelMedium?.copyWith(color: c.accent),
            )
          else
            ProgressBar(value: progress.fraction, height: 5),
        ],
      ),
    );
  }
}

void _showDetails(BuildContext context, AchievementProgress p) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) {
      final c = context.colors;
      final d = p.definition;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UnlockReveal(child: AchievementBadge(definition: d, unlocked: p.isUnlocked, size: 88)),
              const SizedBox(height: 20),
              Text(d.title, style: context.text.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(d.description, style: context.text.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              if (p.isUnlocked)
                Text(
                  'Unlocked on ${Formatters.shortDate(p.unlocked!.unlockedAt)}',
                  style: context.text.labelLarge?.copyWith(color: c.accent),
                )
              else ...[
                ProgressBar(value: p.fraction, height: 8),
                const SizedBox(height: 10),
                Text(_progressText(p), style: context.text.labelLarge),
              ],
            ],
          ),
        ),
      );
    },
  );
}
