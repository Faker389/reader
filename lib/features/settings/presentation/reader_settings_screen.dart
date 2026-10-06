import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/models/reader_settings.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/reader_theme.dart';
import '../../../widgets/segmented.dart';
import '../../../widgets/settings_tiles.dart';
import '../../reader/presentation/widgets/reader_quick_settings.dart';
import '../../reader/presentation/widgets/rsvp_word_view.dart';
import '../../reader/presentation/widgets/wpm_picker.dart';
import '../application/settings_controller.dart';

class ReaderSettingsScreen extends ConsumerWidget {
  const ReaderSettingsScreen({super.key});

  static String _multiplier(double v) => '${v.toStringAsFixed(2)}×';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(readerSettingsProvider);
    final minSession = ref.watch(settingsControllerProvider.select((a) => a.minSessionSeconds));
    final controller = ref.read(settingsControllerProvider.notifier);
    void update(ReaderSettings Function(ReaderSettings) change) => controller.updateReader(change);

    return Scaffold(
      appBar: AppBar(title: const Text('Reader settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _Preview(settings: s),
              const SizedBox(height: 20),
              SettingsSection(
                title: 'Default speed',
                footer: 'Used when you open a book. You can always adjust speed while reading.',
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: WpmPicker(value: s.defaultWpm, onChanged: (v) => update((r) => r.copyWith(defaultWpm: v))),
                  ),
                ],
              ),
              SettingsSection(
                title: 'Display',
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Word size', style: context.text.titleSmall),
                        FontScaleSlider(value: s.fontScale, onChanged: (v) => update((r) => r.copyWith(fontScale: v))),
                        const SizedBox(height: 8),
                        Text('Typeface', style: context.text.titleSmall),
                        const SizedBox(height: 8),
                        SegmentedPills<ReaderFont>(
                          options: [for (final f in ReaderFont.values) SegmentOption(f, f.label)],
                          selected: s.font,
                          onChanged: (f) => update((r) => r.copyWith(font: f)),
                        ),
                        const SizedBox(height: 16),
                        Text('Weight', style: context.text.titleSmall),
                        const SizedBox(height: 8),
                        SegmentedPills<ReaderWeight>(
                          options: [for (final w in ReaderWeight.values) SegmentOption(w, w.label)],
                          selected: s.weight,
                          onChanged: (w) => update((r) => r.copyWith(weight: w)),
                        ),
                        const SizedBox(height: 16),
                        Text('Words at a time', style: context.text.titleSmall),
                        const SizedBox(height: 8),
                        SegmentedPills<int>(
                          options: const [
                            SegmentOption(1, '1'),
                            SegmentOption(2, '2'),
                            SegmentOption(3, '3'),
                          ],
                          selected: s.chunkSize,
                          onChanged: (v) => update((r) => r.copyWith(chunkSize: v)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Two or three words stay on the same focal point, so the sentence is easier to follow.',
                          style: context.text.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        Text('Focal letter', style: context.text.titleSmall),
                        const SizedBox(height: 8),
                        SegmentedPills<FocalMode>(
                          options: [for (final m in FocalMode.values) SegmentOption(m, m.label)],
                          selected: s.focalMode,
                          onChanged: (m) => update((r) => r.copyWith(focalMode: m)),
                        ),
                        const SizedBox(height: 16),
                        Text('Reading theme', style: context.text.titleSmall),
                        const SizedBox(height: 10),
                        ReaderThemeSwatches(
                          selected: s.themeId,
                          onSelected: (id) => update((r) => r.copyWith(themeId: id)),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  SettingsSwitch(
                    title: 'Focal guides',
                    subtitle: 'Small marks above and below the focal letter',
                    value: s.showFocalGuides,
                    onChanged: (v) => update((r) => r.copyWith(showFocalGuides: v)),
                  ),
                  SettingsSwitch(
                    title: 'Show context when paused',
                    subtitle: 'See the surrounding sentence while paused',
                    value: s.showContextWhenPaused,
                    onChanged: (v) => update((r) => r.copyWith(showContextWhenPaused: v)),
                  ),
                ],
              ),
              SettingsSection(
                title: 'Rhythm',
                footer: 'Pauses are multiples of the time each word normally gets. Turn everything off for '
                    'strictly constant timing (60 000 ÷ WPM ms per word).',
                children: [
                  SettingsSwitch(
                    title: 'Pause at commas',
                    value: s.punctuationPauses,
                    onChanged: (v) => update((r) => r.copyWith(punctuationPauses: v)),
                  ),
                  if (s.punctuationPauses)
                    SettingsSlider(
                      title: 'Comma pause',
                      value: s.clauseMultiplier,
                      min: ReaderConstants.minPauseMultiplier,
                      max: 2,
                      divisions: 20,
                      label: _multiplier(s.clauseMultiplier),
                      onChanged: (v) => update((r) => r.copyWith(clauseMultiplier: v)),
                    ),
                  SettingsSwitch(
                    title: 'Pause at sentence ends',
                    value: s.sentencePauses,
                    onChanged: (v) => update((r) => r.copyWith(sentencePauses: v)),
                  ),
                  if (s.sentencePauses)
                    SettingsSlider(
                      title: 'Sentence pause',
                      value: s.sentenceMultiplier,
                      min: ReaderConstants.minPauseMultiplier,
                      max: 2.5,
                      divisions: 30,
                      label: _multiplier(s.sentenceMultiplier),
                      onChanged: (v) => update((r) => r.copyWith(sentenceMultiplier: v)),
                    ),
                  SettingsSwitch(
                    title: 'Pause between paragraphs',
                    value: s.paragraphPauses,
                    onChanged: (v) => update((r) => r.copyWith(paragraphPauses: v)),
                  ),
                  if (s.paragraphPauses)
                    SettingsSlider(
                      title: 'Paragraph pause',
                      value: s.paragraphMultiplier,
                      min: ReaderConstants.minPauseMultiplier,
                      max: ReaderConstants.maxPauseMultiplier,
                      divisions: 20,
                      label: _multiplier(s.paragraphMultiplier),
                      onChanged: (v) => update((r) => r.copyWith(paragraphMultiplier: v)),
                    ),
                  SettingsSwitch(
                    title: 'More time for long words',
                    value: s.longWordAdjustment,
                    onChanged: (v) => update((r) => r.copyWith(longWordAdjustment: v)),
                  ),
                  SettingsSwitch(
                    title: 'Smooth speed changes',
                    subtitle: 'Ease into a new speed over a few words',
                    value: s.smoothSpeedChanges,
                    onChanged: (v) => update((r) => r.copyWith(smoothSpeedChanges: v)),
                  ),
                ],
              ),
              SettingsSection(
                title: 'Behaviour',
                children: [
                  SettingsSwitch(
                    title: 'Read the words aloud',
                    subtitle: 'Speaks the words on screen. Past about 300 words per minute they move on before they can be said, so the voice stays quiet instead of falling behind.',
                    value: s.readAloud,
                    onChanged: (v) => update((r) => r.copyWith(readAloud: v)),
                  ),
                  SettingsSwitch(
                    title: 'Training',
                    subtitle: 'Ease the saved speed up after calm sessions, and down after a lot of rewinding',
                    value: s.trainingMode,
                    onChanged: (v) => update((r) => r.copyWith(trainingMode: v)),
                  ),
                  SettingsSwitch(
                    title: 'Continue into next chapter',
                    subtitle: 'Off: pause at the end of each chapter',
                    value: s.autoStartNextChapter,
                    onChanged: (v) => update((r) => r.copyWith(autoStartNextChapter: v)),
                  ),
                  SettingsSwitch(
                    title: 'Keep screen awake',
                    subtitle: 'While words are playing',
                    value: s.keepScreenAwake,
                    onChanged: (v) => update((r) => r.copyWith(keepScreenAwake: v)),
                  ),
                  SettingsSwitch(
                    title: 'Haptic feedback',
                    value: s.hapticFeedback,
                    onChanged: (v) => update((r) => r.copyWith(hapticFeedback: v)),
                  ),
                ],
              ),
              SettingsSection(
                title: 'Sessions',
                footer: 'Shorter reading is still saved to your book progress, but not logged as a session.',
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Minimum session length', style: context.text.titleSmall),
                        const SizedBox(height: 10),
                        SegmentedPills<int>(
                          options: [
                            for (final secs in SessionConstants.minMeaningfulOptions)
                              SegmentOption(secs, secs < 60 ? '${secs}s' : '${secs ~/ 60} min'),
                          ],
                          selected: minSession,
                          onChanged: (v) => controller.update((a) => a.copyWith(minSessionSeconds: v)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Center(
                child: TextButton(
                  onPressed: () => update((r) => ReaderSettings(defaultWpm: r.defaultWpm)),
                  child: const Text('Restore defaults'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Preview extends StatefulWidget {
  const _Preview({required this.settings});

  final ReaderSettings settings;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  static const _words = ['Reading', 'in', 'phrases'];
  final ValueNotifier<int> _position = ValueNotifier(0);

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final theme = ReaderTheme.of(s.themeId);
    final size = 44 * s.fontScale;
    return AnimatedContainer(
      duration: MotionConstants.medium,
      height: 130,
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(LayoutConstants.cardRadius),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.6), width: 0.5),
      ),
      alignment: Alignment.center,
      child: RsvpWordView(
        words: _words,
        position: _position,
        chunkSize: s.chunkSize,
        height: 120,
        style: RsvpWordStyle(
          text: AppTypography.readerStyle(
            s.font,
            size: size,
            weight: FontWeight.values[(s.weight.value ~/ 100) - 1],
          ),
          wordColor: theme.word,
          focalColor: theme.focal,
          guideColor: theme.guide,
          focalMode: s.focalMode,
          showGuides: s.showFocalGuides,
        ),
      ),
    );
  }
}
