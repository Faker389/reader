import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/reading/wpm_scale.dart';
import '../../../../theme/app_typography.dart';
import '../../../../theme/reader_theme.dart';
import '../../engine/rsvp_engine.dart';

/// Top bar: close, title / chapter (opens chapter list), display settings,
/// and a hairline progress bar.
class ReaderTopBar extends StatelessWidget {
  const ReaderTopBar({
    required this.engine,
    required this.title,
    required this.theme,
    required this.onClose,
    required this.onChapters,
    required this.onDisplaySettings,
    super.key,
  });

  final RsvpEngine engine;
  final String title;
  final ReaderTheme theme;
  final VoidCallback onClose;
  final VoidCallback onChapters;
  final VoidCallback onDisplaySettings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _ChromeButton(icon: Icons.close_rounded, tooltip: 'End session', theme: theme, onTap: onClose),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Chapters and position',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onChapters,
                    child: ValueListenableBuilder<int>(
                      valueListenable: engine.position,
                      builder: (context, position, _) {
                        final content = engine.content;
                        final chapter = content.chapters.isEmpty
                            ? ''
                            : content.chapters[content.chapterIndexAt(position)].title;
                        return Column(
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleSmall?.copyWith(color: theme.chrome),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    chapter,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodySmall?.copyWith(color: theme.chromeMuted),
                                  ),
                                ),
                                Icon(Icons.expand_more_rounded, size: 16, color: theme.chromeMuted),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              _ChromeButton(
                icon: Icons.text_fields_rounded,
                tooltip: 'Display settings',
                theme: theme,
                onTap: onDisplaySettings,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ValueListenableBuilder<int>(
              valueListenable: engine.position,
              builder: (context, position, _) {
                final total = engine.content.length;
                final fraction = total <= 1 ? 0.0 : position / (total - 1);
                return Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 3,
                          color: theme.focal,
                          backgroundColor: theme.guide,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      Formatters.percent(fraction),
                      style: AppTypography.numeric(textTheme.labelMedium!.copyWith(color: theme.chromeMuted)),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom panel: live stats, WPM slider with ± buttons, transport controls.
class ReaderBottomPanel extends StatelessWidget {
  const ReaderBottomPanel({
    required this.engine,
    required this.theme,
    required this.onTogglePlay,
    required this.onSkip,
    required this.onWpmChanged,
    required this.onOpenWpm,
    super.key,
  });

  final RsvpEngine engine;
  final ReaderTheme theme;
  final VoidCallback onTogglePlay;
  final ValueChanged<int> onSkip;
  final ValueChanged<int> onWpmChanged;
  final VoidCallback onOpenWpm;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final statValue = AppTypography.numeric(textTheme.titleMedium!.copyWith(color: theme.chrome));
    final statLabel = textTheme.labelSmall!.copyWith(color: theme.chromeMuted);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<int>(
            valueListenable: engine.position,
            builder: (context, _, __) => Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Speed ${engine.wpm.value} words per minute. Tap to change.',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: onOpenWpm,
                      child: ValueListenableBuilder<int>(
                        valueListenable: engine.wpm,
                        builder: (context, wpm, _) => _Stat(value: '$wpm', label: 'WPM', valueStyle: statValue.copyWith(color: theme.focal), labelStyle: statLabel),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _Stat(
                    value: Formatters.clock(engine.activeDuration),
                    label: 'ELAPSED',
                    valueStyle: statValue,
                    labelStyle: statLabel,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    value: Formatters.compact(engine.wordsRemaining),
                    label: 'WORDS LEFT',
                    valueStyle: statValue,
                    labelStyle: statLabel,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<int>(
            valueListenable: engine.wpm,
            builder: (context, wpm, _) => Row(
              children: [
                _ChromeButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Slower',
                  theme: theme,
                  onTap: wpm <= ReaderConstants.minWpm ? null : () => onWpmChanged(WpmScale.step(wpm, -1)),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: theme.focal,
                      inactiveTrackColor: theme.guide,
                      thumbColor: theme.chrome,
                      overlayColor: theme.focal.withValues(alpha: 0.12),
                    ),
                    child: Slider(
                      value: WpmScale.indexOf(wpm).toDouble(),
                      max: (WpmScale.values.length - 1).toDouble(),
                      divisions: WpmScale.values.length - 1,
                      semanticFormatterCallback: (v) => '${WpmScale.values[v.round()]} words per minute',
                      onChanged: (v) => onWpmChanged(WpmScale.values[v.round()]),
                    ),
                  ),
                ),
                _ChromeButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Faster',
                  theme: theme,
                  onTap: wpm >= ReaderConstants.maxWpm ? null : () => onWpmChanged(WpmScale.step(wpm, 1)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ChromeButton(
                icon: Icons.replay_10_rounded,
                tooltip: 'Back ${ReaderConstants.skipWordCount} words',
                theme: theme,
                size: 56,
                iconSize: 28,
                onTap: () => onSkip(-ReaderConstants.skipWordCount),
              ),
              const SizedBox(width: 28),
              ValueListenableBuilder<bool>(
                valueListenable: engine.playing,
                builder: (context, playing, _) => _PlayButton(playing: playing, theme: theme, onTap: onTogglePlay),
              ),
              const SizedBox(width: 28),
              _ChromeButton(
                icon: Icons.forward_10_rounded,
                tooltip: 'Forward ${ReaderConstants.skipWordCount} words',
                theme: theme,
                size: 56,
                iconSize: 28,
                onTap: () => onSkip(ReaderConstants.skipWordCount),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.valueStyle, required this.labelStyle});

  final String value;
  final String label;
  final TextStyle valueStyle;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value, style: valueStyle),
          const SizedBox(height: 2),
          Text(label, style: labelStyle),
        ],
      );
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.theme, required this.onTap});

  final bool playing;
  final ReaderTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: playing ? 'Pause' : 'Play',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(color: theme.chrome, shape: BoxShape.circle),
          child: AnimatedSwitcher(
            duration: MotionConstants.fast,
            transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              key: ValueKey(playing),
              size: 40,
              color: theme.background,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChromeButton extends StatelessWidget {
  const _ChromeButton({
    required this.icon,
    required this.tooltip,
    required this.theme,
    required this.onTap,
    this.size = 44,
    this.iconSize = 22,
  });

  final IconData icon;
  final String tooltip;
  final ReaderTheme theme;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      iconSize: iconSize,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      color: theme.chrome,
      disabledColor: theme.chromeMuted.withValues(alpha: 0.4),
      style: IconButton.styleFrom(backgroundColor: theme.guide.withValues(alpha: 0.5)),
      icon: Icon(icon),
    );
  }
}
