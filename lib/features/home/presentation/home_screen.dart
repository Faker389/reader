import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/providers.dart';
import '../../../domain/models/book.dart';
import '../../../domain/stats/reading_stats.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/progress.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/stat_tile.dart';
import '../../library/presentation/widgets/book_widgets.dart';
import '../../statistics/application/stats_providers.dart';
import 'main_shell.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static String greeting(DateTime now) {
    final h = now.hour;
    if (h < 5) return 'Good night';
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final stats = ref.watch(readingStatsProvider);
    final goal = ref.watch(goalMinutesProvider);
    final continueBook = ref.watch(continueBookProvider);
    final books = ref.watch(booksProvider).value ?? const <Book>[];

    final unread = books.where((b) => !b.isStarted && !b.completed && b.contentAvailable).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final inProgress = books.where((b) => b.isInProgress && b.id != continueBook?.id).toList()
      ..sort((a, b) => (b.lastOpenedAt ?? b.updatedAt).compareTo(a.lastOpenedAt ?? a.updatedAt));

    return Scaffold(
      body: Stack(
        children: [
          const Positioned(top: -180, right: -140, child: AccentGlow(size: 440, opacity: 0.14)),
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: LayoutConstants.maxContentWidth),
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      sliver: SliverList.list(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${greeting(DateTime.now())}, ${profile?.firstName ?? 'reader'}',
                                      style: context.text.headlineMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      continueBook != null
                                          ? 'Ready for a few more pages?'
                                          : 'Pick a book and press play.',
                                      style: context.text.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              CircleIconButton(
                                icon: Icons.add_rounded,
                                tooltip: 'Import a book',
                                onPressed: () => context.push(Routes.import),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          if (continueBook != null) ...[
                            const Eyebrow('Continue reading'),
                            const SizedBox(height: 10),
                            ContinueReadingCard(book: continueBook),
                          ] else
                            _StartCard(suggestion: unread.isEmpty ? null : unread.first),
                          const SizedBox(height: 14),
                          _TodayCard(stats: stats, goalMinutes: goal),
                          const SizedBox(height: 14),
                          if (stats.hasData)
                            StatGrid(
                              children: [
                                StatTile(
                                  label: 'Words read',
                                  value: Formatters.compact(stats.totalWords),
                                  icon: Icons.text_fields_rounded,
                                ),
                                StatTile(
                                  label: 'Average WPM',
                                  value: '${stats.averageWpm}',
                                  icon: Icons.speed_rounded,
                                ),
                                StatTile(
                                  label: 'Reading time',
                                  value: Formatters.duration(Duration(seconds: stats.totalSeconds)),
                                  icon: Icons.schedule_rounded,
                                ),
                                StatTile(
                                  label: 'Books finished',
                                  value: '${stats.booksCompleted}',
                                  icon: Icons.menu_book_rounded,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    if (inProgress.isNotEmpty) ...[
                      const SliverToBoxAdapter(child: SectionHeader(title: 'Also reading')),
                      SliverToBoxAdapter(child: _Shelf(books: inProgress)),
                    ],
                    if (unread.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: SectionHeader(
                          title: 'Up next',
                          actionLabel: 'Library',
                          onAction: () => context.go(Routes.library),
                        ),
                      ),
                      SliverToBoxAdapter(child: _Shelf(books: unread)),
                    ],
                    SliverToBoxAdapter(child: SizedBox(height: shellBottomInset(context))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartCard extends StatelessWidget {
  const _StartCard({required this.suggestion});

  final Book? suggestion;

  @override
  Widget build(BuildContext context) {
    final book = suggestion;
    return AppCard(
      gradient: LinearGradient(
        colors: [context.colors.accent.withValues(alpha: 0.22), context.colors.card],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Start here'),
          const SizedBox(height: 8),
          Text(
            book == null ? 'Your library is waiting.' : 'Begin with ${book.title}',
            style: context.text.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            book == null
                ? 'Import an EPUB, TXT or CSV file to start reading.'
                : 'A few minutes is enough to feel the rhythm.',
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: book == null ? 'Import a book' : 'Start reading',
            icon: book == null ? Icons.add_rounded : Icons.play_arrow_rounded,
            expand: false,
            height: 48,
            onPressed: () => book == null ? context.push(Routes.import) : openBook(context, book),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.stats, required this.goalMinutes});

  final ReadingStats stats;
  final int goalMinutes;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = stats.today();
    final minutes = today.seconds ~/ 60;
    final fraction = goalMinutes == 0 ? 0.0 : today.seconds / (goalMinutes * 60);
    final streak = stats.streak;
    final met = fraction >= 1;

    final streakMessage = streak.current == 0
        ? 'Meet your goal today to start a streak.'
        : streak.todayMet
            ? 'Streak kept for today. See you tomorrow.'
            : 'Read ${(goalMinutes - minutes).clamp(1, goalMinutes)} more min to keep it going.';

    return AppCard(
      onTap: () => context.go(Routes.statistics),
      semanticLabel: "Today's progress: $minutes of $goalMinutes minutes",
      child: Row(
        children: [
          ProgressRing(
            value: fraction,
            size: 84,
            strokeWidth: 8,
            child: Icon(
              met ? Icons.check_rounded : Icons.auto_stories_rounded,
              color: met ? c.success : c.muted,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('Today'),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '$minutes', style: AppTypography.numeric(context.text.headlineMedium!)),
                      TextSpan(text: ' / $goalMinutes min', style: context.text.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(streak.current > 0 ? '🔥' : '·', style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      streak.current == 1 ? '1 day' : '${streak.current} days',
                      style: context.text.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(streakMessage, style: context.text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({required this.books});

  final List<Book> books;

  @override
  Widget build(BuildContext context) {
    const width = 116.0;
    return SizedBox(
      height: width / (2 / 3) + 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: books.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) => BookShelfCard(book: books[i], width: width),
      ),
    );
  }
}
