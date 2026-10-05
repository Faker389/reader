import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/stats/period_stats.dart';
import '../../../domain/stats/reading_stats.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/segmented.dart';
import '../../../widgets/stat_tile.dart';
import '../../../widgets/states.dart';
import '../../home/presentation/main_shell.dart';
import '../application/stats_providers.dart';
import 'charts.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  StatsPeriod _period = StatsPeriod.week;

  @override
  Widget build(BuildContext context) {
    final lifetime = ref.watch(readingStatsProvider);
    final stats = ref.watch(periodStatsProvider(_period));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: LayoutConstants.maxContentWidth),
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, shellBottomInset(context)),
              children: [
                Text('Statistics', style: context.text.displaySmall),
                const SizedBox(height: 20),
                if (!lifetime.hasData)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: EmptyState(
                      icon: Icons.insights_rounded,
                      title: 'No reading yet',
                      message: 'Start your first session to see your reading stats.',
                      actionLabel: 'Go to Library',
                      onAction: () => context.go(Routes.library),
                    ),
                  )
                else ...[
                  SegmentedPills<StatsPeriod>(
                    options: [
                      for (final p in StatsPeriod.values)
                        SegmentOption(p, p == StatsPeriod.allTime ? 'All' : p.label.replaceFirst('This ', '')),
                    ],
                    selected: _period,
                    onChanged: (p) => setState(() => _period = p),
                  ),
                  const SizedBox(height: 20),
                  _Insights(lifetime: lifetime),
                  StatGrid(
                    children: [
                      StatTile(
                        label: 'Reading time',
                        value: Formatters.duration(Duration(seconds: stats.totalSeconds)),
                        icon: Icons.schedule_rounded,
                      ),
                      StatTile(
                        label: 'Words read',
                        value: Formatters.compact(stats.totalWords),
                        icon: Icons.text_fields_rounded,
                      ),
                      StatTile(
                        label: 'Average WPM',
                        value: stats.averageWpm == 0 ? '—' : '${stats.averageWpm}',
                        icon: Icons.speed_rounded,
                      ),
                      StatTile(
                        label: 'Highest WPM',
                        value: stats.highestWpm == 0 ? '—' : '${stats.highestWpm}',
                        caption: 'Sessions of 1 min+',
                        icon: Icons.trending_up_rounded,
                      ),
                      StatTile(
                        label: 'Sessions',
                        value: '${stats.sessions}',
                        icon: Icons.play_circle_outline_rounded,
                      ),
                      StatTile(
                        label: 'Avg. session',
                        value: Formatters.duration(Duration(seconds: stats.averageSessionSeconds)),
                        icon: Icons.timelapse_rounded,
                      ),
                      StatTile(
                        label: 'Longest session',
                        value: Formatters.duration(Duration(seconds: stats.longestSessionSeconds)),
                        icon: Icons.hourglass_bottom_rounded,
                      ),
                      StatTile(
                        label: 'Books finished',
                        value: '${stats.booksCompleted}',
                        icon: Icons.menu_book_rounded,
                      ),
                    ],
                  ),
                  if (!stats.hasData)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Text(
                        'No sessions ${_period == StatsPeriod.today ? 'today' : 'in this period'} yet.',
                        textAlign: TextAlign.center,
                        style: context.text.bodyMedium,
                      ),
                    )
                  else ...[
                    _ChartCard(title: 'Minutes read', child: BarChart(points: stats.minutesSeries)),
                    _ChartCard(title: 'Words read', child: BarChart(points: stats.wordsSeries)),
                    if (stats.wpmSeries.length >= 2)
                      _ChartCard(
                        title: 'Speed by session',
                        subtitle: 'Average WPM, most recent ${stats.wpmSeries.length} sessions',
                        child: LineChart(points: _thinLabels(stats.wpmSeries)),
                      ),
                    if (stats.booksCompleted > 0)
                      _ChartCard(
                        title: 'Books finished',
                        child: BarChart(points: stats.booksSeries, height: 110, highlightLast: false),
                      ),
                  ],
                  const SizedBox(height: 12),
                  _StreakCard(streak: lifetime.streak),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static List<ChartPoint> _thinLabels(List<ChartPoint> points) {
    final keep = {0, points.length ~/ 2, points.length - 1};
    return [
      for (var i = 0; i < points.length; i++) ChartPoint(keep.contains(i) ? points[i].label : '', points[i].value),
    ];
  }
}

class _Insights extends StatelessWidget {
  const _Insights({required this.lifetime});

  final ReadingStats lifetime;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final improvement = lifetime.speedImprovement;
    // Only shown when backed by enough sessions; see StatsCalculator.
    if (improvement == null || improvement <= 0) return const SizedBox.shrink();
    final percent = (improvement * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        gradient: LinearGradient(
          colors: [c.success.withValues(alpha: 0.18), c.card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        child: Row(
          children: [
            Icon(Icons.trending_up_rounded, color: c.success, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('You read $percent% faster than when you started.', style: context.text.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Comparing your first and most recent sessions.',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.text.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: context.text.bodySmall),
            ],
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});

  final StreakInfo streak;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 22)),
                const SizedBox(height: 6),
                Text('${streak.current} ${streak.current == 1 ? 'day' : 'days'}', style: context.text.headlineSmall),
                Text('Current streak', style: context.text.bodySmall),
              ],
            ),
          ),
          Container(width: 0.5, height: 64, color: c.border),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.workspace_premium_rounded, color: c.accent),
                const SizedBox(height: 6),
                Text('${streak.longest} ${streak.longest == 1 ? 'day' : 'days'}', style: context.text.headlineSmall),
                Text('Longest streak', style: context.text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
