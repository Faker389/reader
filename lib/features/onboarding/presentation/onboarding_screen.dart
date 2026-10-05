import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers.dart';
import '../../../routing/routes.dart';
import '../../../services/analytics_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/motion.dart';
import '../../../widgets/pressable.dart';
import '../../settings/application/settings_controller.dart';
import 'rsvp_demo.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const int _introPages = 4;
  static const int _pageCount = _introPages + 2;

  final PageController _pages = PageController();
  int _index = 0;
  bool _finishing = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < _pageCount - 1) {
      _pages.nextPage(duration: context.motion(MotionConstants.medium), curve: Curves.easeOutCubic);
    } else {
      _finish(Routes.signUp);
    }
  }

  Future<void> _finish(String destination) async {
    if (_finishing) return;
    setState(() => _finishing = true);
    // Completing onboarding triggers a redirect that disposes this screen,
    // so the router is captured first.
    final router = GoRouter.of(context);
    final analytics = ref.read(analyticsProvider);
    final choices = ref.read(onboardingProvider);
    await ref.read(onboardingProvider.notifier).complete();
    await analytics.log(AnalyticsEvents.onboardingCompleted, {
      'goal_minutes': choices.goalMinutes,
      'starting_wpm': choices.startingWpm,
    });
    router.go(destination);
  }

  @override
  Widget build(BuildContext context) {
    final choices = ref.watch(onboardingProvider);
    final onIntro = _index < _introPages;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned(top: -140, left: -100, child: AccentGlow(size: 420, opacity: 0.16)),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                      child: Row(
                        children: [
                          _PageDots(count: _pageCount, index: _index),
                          const Spacer(),
                          TextButton(
                            onPressed: _finishing ? null : () => _finish(Routes.signIn),
                            child: const Text('I have an account'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pages,
                        onPageChanged: (i) => setState(() => _index = i),
                        children: [
                          _IntroPage(
                            title: 'Read differently.',
                            body: 'One word at a time, always in the same place. '
                                'Your eyes stay still — the words come to you.',
                            visual: RsvpDemo(
                              text: 'Your eyes stay still. The words come to you, one at a time.',
                              playing: _index == 0,
                            ),
                          ),
                          _IntroPage(
                            title: 'Train your reading speed.',
                            body: 'Set your own pace and adjust it as you go. '
                                'Comfort and comprehension come first; speed follows.',
                            visual: _SpeedVisual(active: _index == 1),
                          ),
                          const _IntroPage(
                            title: 'Build a reading habit.',
                            body: 'A small daily goal, gentle streaks and clear progress. '
                                'Ten focused minutes add up to whole books.',
                            visual: _HabitVisual(),
                          ),
                          const _IntroPage(
                            title: 'Import your own books.',
                            body: 'Bring EPUB, TXT or CSV files. They stay private on your device '
                                '— only your progress syncs.',
                            visual: _ImportVisual(),
                          ),
                          _ChoicePage(
                            title: 'How much would you like to read each day?',
                            subtitle: 'You can change this any time.',
                            children: [
                              for (final minutes in GoalConstants.dailyMinuteOptions)
                                _ChoiceTile(
                                  label: '$minutes minutes',
                                  caption: switch (minutes) {
                                    10 => 'A gentle start',
                                    20 => 'Steady habit',
                                    30 => 'Committed reader',
                                    45 => 'Deep focus',
                                    _ => 'Bookworm',
                                  },
                                  selected: choices.goalMinutes == minutes,
                                  onTap: () => ref.read(onboardingProvider.notifier).setGoal(minutes),
                                ),
                            ],
                          ),
                          _ChoicePage(
                            title: 'Pick a starting speed.',
                            subtitle: 'Most people read printed text at around 200–300 words per minute. '
                                'Start where reading feels comfortable — 250 is a good default.',
                            children: [
                              for (final wpm in GoalConstants.startingWpmOptions)
                                _ChoiceTile(
                                  label: '$wpm WPM',
                                  caption: switch (wpm) {
                                    150 => 'Relaxed',
                                    200 => 'Easy',
                                    250 => 'Comfortable',
                                    300 => 'Brisk',
                                    400 => 'Fast',
                                    _ => 'Very fast — for practised readers',
                                  },
                                  recommended: wpm == ReaderConstants.defaultWpm,
                                  selected: choices.startingWpm == wpm,
                                  onTap: () => ref.read(onboardingProvider.notifier).setStartingWpm(wpm),
                                ),
                              const SizedBox(height: 8),
                              AppCard(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Text('Preview', style: context.text.labelSmall),
                                    RsvpDemo(
                                      text: 'This is how your chosen speed feels. '
                                          'Adjust it any time while reading.',
                                      wpm: choices.startingWpm,
                                      fontSize: 34,
                                      playing: _index == _pageCount - 1,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: PrimaryButton(
                        label: onIntro ? 'Continue' : (_index == _pageCount - 1 ? 'Start reading' : 'Next'),
                        loading: _finishing,
                        onPressed: _next,
                      ),
                    ),
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

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: 'Step ${index + 1} of $count',
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: context.motion(MotionConstants.medium),
              margin: const EdgeInsets.only(right: 6),
              width: i == index ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i <= index ? c.accent : c.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({required this.title, required this.body, required this.visual});

  final String title;
  final String body;
  final Widget visual;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 220, child: Center(child: visual)),
              const SizedBox(height: 36),
              Text(title, style: context.text.displaySmall),
              const SizedBox(height: 14),
              Text(body, style: context.text.bodyLarge?.copyWith(color: context.colors.muted)),
            ],
          ),
        ),
      );
    });
  }
}

class _SpeedVisual extends StatefulWidget {
  const _SpeedVisual({required this.active});

  final bool active;

  @override
  State<_SpeedVisual> createState() => _SpeedVisualState();
}

class _SpeedVisualState extends State<_SpeedVisual> {
  int _wpm = 250;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RsvpDemo(text: 'Find the pace that feels natural, then nudge it.', wpm: _wpm, playing: widget.active),
        Row(
          children: [
            Text('$_wpm', style: context.text.titleLarge?.copyWith(color: c.accent)),
            const SizedBox(width: 6),
            Text('WPM', style: context.text.labelMedium),
            Expanded(
              child: Slider(
                value: _wpm.toDouble(),
                min: 150,
                max: 450,
                divisions: 12,
                onChanged: (v) => setState(() => _wpm = v.round()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HabitVisual extends StatelessWidget {
  const _HabitVisual();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const filled = [true, true, true, false, true, true, true];
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 7; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: filled[i] ? c.accentGradient : null,
                    color: filled[i] ? null : c.surface,
                  ),
                  child: filled[i] ? Icon(Icons.check_rounded, size: 18, color: c.onAccent) : null,
                ),
                const SizedBox(height: 8),
                Text(labels[i], style: context.text.labelMedium),
              ],
            ),
          ),
      ],
    );
  }
}

class _ImportVisual extends StatelessWidget {
  const _ImportVisual();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget chip(String label, double angle, Color color) => Transform.rotate(
          angle: angle,
          child: Container(
            width: 84,
            height: 112,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.6)),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.description_outlined, color: color),
                const SizedBox(height: 8),
                Text(label, style: context.text.labelLarge?.copyWith(color: color)),
              ],
            ),
          ),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        chip('TXT', -0.12, c.muted),
        chip('EPUB', 0, c.accent),
        chip('CSV', 0.12, c.accentSecondary),
      ],
    );
  }
}

class _ChoicePage extends StatelessWidget {
  const _ChoicePage({required this.title, required this.subtitle, required this.children});

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      children: [
        Text(title, style: context.text.headlineLarge),
        const SizedBox(height: 10),
        Text(subtitle, style: context.text.bodyMedium),
        const SizedBox(height: 24),
        ...children,
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.caption,
    required this.selected,
    required this.onTap,
    this.recommended = false,
  });

  final String label;
  final String caption;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        selected: selected,
        child: Pressable(
          onTap: onTap,
          semanticLabel: '$label, $caption',
          child: AnimatedContainer(
            duration: context.motion(MotionConstants.fast),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: selected ? c.accent.withValues(alpha: 0.14) : c.card,
              borderRadius: BorderRadius.circular(LayoutConstants.smallRadius + 4),
              border: Border.all(color: selected ? c.accent : c.border, width: selected ? 1.5 : 0.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: context.text.titleMedium),
                      const SizedBox(height: 2),
                      Text(caption, style: context.text.bodySmall),
                    ],
                  ),
                ),
                if (recommended)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Suggested', style: context.text.labelSmall?.copyWith(color: c.success)),
                  ),
                AnimatedSwitcher(
                  duration: context.motion(MotionConstants.fast),
                  child: Icon(
                    selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                    key: ValueKey(selected),
                    color: selected ? c.accent : c.subtle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
