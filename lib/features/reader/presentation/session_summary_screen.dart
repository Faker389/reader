import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/reading/comprehension_quiz.dart';
import '../../../domain/reading/training_pace.dart';
import '../../../routing/routes.dart';
import '../../../services/session_recorder.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/progress.dart';
import '../../../widgets/section_header.dart';
import '../../achievements/presentation/achievement_badge.dart';
import '../../settings/application/settings_controller.dart';

class SessionSummaryScreen extends StatelessWidget {
  const SessionSummaryScreen({required this.summary, super.key});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = summary.session;
    final goalSeconds = summary.goalMinutes * 60;
    final minutesAdded = (s.durationSeconds / 60).round();

    return Scaffold(
      body: Stack(
        children: [
          const Positioned(top: -120, right: -80, child: AccentGlow(size: 360)),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: LayoutConstants.maxContentWidth),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                  children: [
                    Eyebrow(summary.bookCompleted ? 'Book finished' : 'Session complete', color: c.accent),
                    const SizedBox(height: 8),
                    Text(
                      summary.bookCompleted ? 'What a finish.' : 'Nice session.',
                      style: context.text.displaySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(s.bookTitle, style: context.text.bodyMedium),
                    const SizedBox(height: 28),
                    _GoalCard(summary: summary, goalSeconds: goalSeconds),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _Metric(
                            value: Formatters.durationLong(s.duration),
                            label: 'Reading time',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CountMetric(value: s.wordsRead, label: 'Words', format: Formatters.number),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _CountMetric(value: s.averageWpm, label: 'WPM average')),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Metric(
                            value: '+${minutesAdded < 1 ? '<1' : minutesAdded} min',
                            label: 'Toward today',
                            valueColor: c.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Book progress', style: context.text.titleSmall),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Text(Formatters.percent(summary.progressBefore), style: context.text.bodyMedium),
                              Icon(Icons.arrow_forward_rounded, size: 16, color: c.subtle),
                              Text(
                                Formatters.percent(summary.progressAfter),
                                style: AppTypography.numeric(context.text.titleMedium!),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ProgressBar(value: summary.progressAfter, from: summary.progressBefore, height: 8),
                        ],
                      ),
                    ),
                    if (summary.trainedToWpm != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Training moved your speed to ${summary.trainedToWpm} WPM.',
                        style: context.text.bodyMedium,
                      ),
                    ],
                    if (summary.questions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _ComprehensionCard(questions: summary.questions),
                    ],
                    if (summary.streakAfter > summary.streakBefore) ...[
                      const SizedBox(height: 12),
                      UnlockReveal(
                        delay: const Duration(milliseconds: 500),
                        child: AppCard(
                          child: Row(
                            children: [
                              Icon(Icons.local_fire_department_rounded, color: c.warning, size: 28),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  summary.streakAfter == 1
                                      ? 'Day one of a new streak.'
                                      : 'Streak extended to ${summary.streakAfter} days.',
                                  style: context.text.titleMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (summary.newAchievements.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Text('Unlocked', style: context.text.titleLarge),
                      const SizedBox(height: 12),
                      for (final (i, a) in summary.newAchievements.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: UnlockReveal(
                            delay: Duration(milliseconds: 700 + i * 180),
                            child: AppCard(
                              child: Row(
                                children: [
                                  AchievementBadge(definition: a, unlocked: true, size: 48),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(a.title, style: context.text.titleMedium),
                                        Text(a.description, style: context.text.bodySmall),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 32),
                    if (!summary.bookCompleted) ...[
                      PrimaryButton(
                        label: 'Continue',
                        icon: Icons.play_arrow_rounded,
                        onPressed: () => context.pushReplacement(Routes.reader(summary.book.id)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SecondaryButton(label: 'Finish for now', onPressed: () => context.go(Routes.home)),
                    const SizedBox(height: 4),
                    TextButton(onPressed: () => context.go(Routes.library), child: const Text('Back to Library')),
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

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.summary, required this.goalSeconds});

  final SessionSummary summary;
  final int goalSeconds;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final before = goalSeconds == 0 ? 0.0 : summary.todaySecondsBefore / goalSeconds;
    final after = goalSeconds == 0 ? 0.0 : summary.todaySecondsAfter / goalSeconds;
    final minutesToday = (summary.todaySecondsAfter / 60).floor();
    final reached = summary.todaySecondsAfter >= goalSeconds;
    return AppCard(
      child: Row(
        children: [
          ProgressRing(
            value: after,
            from: before,
            size: 96,
            strokeWidth: 9,
            duration: MotionConstants.celebration,
            child: Icon(
              reached ? Icons.check_rounded : Icons.timer_outlined,
              color: reached ? c.success : c.muted,
              size: 30,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$minutesToday / ${summary.goalMinutes} min',
                  style: AppTypography.numeric(context.text.headlineSmall!),
                ),
                const SizedBox(height: 4),
                Text(
                  summary.goalReachedThisSession
                      ? "Today's goal reached."
                      : reached
                          ? 'Goal already met today — this is a bonus.'
                          : '${(summary.goalMinutes - minutesToday).clamp(1, summary.goalMinutes)} min to go today.',
                  style: context.text.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label, this.valueColor});

  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: AppTypography.numeric(context.text.titleLarge!.copyWith(color: valueColor)),
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: context.text.bodySmall),
          ],
        ),
      );
}

class _CountMetric extends StatelessWidget {
  const _CountMetric({required this.value, required this.label, this.format});

  final int value;
  final String label;
  final String Function(int)? format;

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedCount(
              value: value,
              format: format,
              style: AppTypography.numeric(context.text.titleLarge!),
            ),
            const SizedBox(height: 4),
            Text(label, style: context.text.bodySmall),
          ],
        ),
      );
}

class _ComprehensionCard extends ConsumerStatefulWidget {
  const _ComprehensionCard({required this.questions});

  final List<ClozeQuestion> questions;

  @override
  ConsumerState<_ComprehensionCard> createState() => _ComprehensionCardState();
}

class _ComprehensionCardState extends ConsumerState<_ComprehensionCard> {
  int _index = 0;
  int _correct = 0;
  String? _picked;
  bool _done = false;
  int? _movedTo;

  void _pick(String choice) {
    if (_picked != null) return;
    setState(() {
      _picked = choice;
      if (choice == widget.questions[_index].answer) _correct++;
    });
  }

  void _next() {
    if (_index + 1 >= widget.questions.length) {
      final settings = ref.read(readerSettingsProvider);
      int? moved;
      if (settings.trainingMode) {
        final next = TrainingPace.fromQuiz(
          current: settings.defaultWpm,
          correct: _correct,
          asked: widget.questions.length,
        );
        if (next != settings.defaultWpm) {
          ref.read(settingsControllerProvider.notifier).updateReader((r) => r.copyWith(defaultWpm: next));
          moved = next;
        }
      }
      setState(() {
        _done = true;
        _movedTo = moved;
      });
      return;
    }
    setState(() {
      _index++;
      _picked = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_done) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Did that stick?', style: context.text.titleSmall),
            const SizedBox(height: 8),
            Text('$_correct of ${widget.questions.length} remembered.', style: context.text.bodyMedium),
            if (_movedTo != null) ...[
              const SizedBox(height: 6),
              Text('Training moved your speed to $_movedTo WPM.', style: context.text.bodySmall),
            ],
          ],
        ),
      );
    }
    final question = widget.questions[_index];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Did that stick?', style: context.text.titleSmall),
          const SizedBox(height: 8),
          Text('${question.before} ____ ${question.after}'.trim(), style: context.text.bodyLarge),
          const SizedBox(height: 12),
          for (final choice in question.choices)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _picked == null ? () => _pick(choice) : null,
                  child: Text(
                    choice,
                    style: TextStyle(
                      color: _picked == null
                          ? null
                          : choice == question.answer
                              ? c.success
                              : choice == _picked
                                  ? c.danger
                                  : null,
                    ),
                  ),
                ),
              ),
            ),
          if (_picked != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _next,
                child: Text(_index + 1 == widget.questions.length ? 'See result' : 'Next'),
              ),
            ),
        ],
      ),
    );
  }
}
