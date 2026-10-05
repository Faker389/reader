import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../domain/models/reader_settings.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/reader_theme.dart';
import '../../../../widgets/segmented.dart';
import '../../../settings/application/settings_controller.dart';

/// In-reader "Aa" sheet for the settings people adjust mid-session.
class ReaderQuickSettings extends ConsumerWidget {
  const ReaderQuickSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(readerSettingsProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reading display', style: context.text.titleLarge),
            const SizedBox(height: 20),
            FontScaleSlider(
              value: s.fontScale,
              onChanged: (v) => controller.updateReader((r) => r.copyWith(fontScale: v)),
            ),
            const SizedBox(height: 12),
            SegmentedPills<ReaderFont>(
              options: [for (final f in ReaderFont.values) SegmentOption(f, f.label)],
              selected: s.font,
              onChanged: (f) => controller.updateReader((r) => r.copyWith(font: f)),
            ),
            const SizedBox(height: 20),
            Text('FOCAL LETTER', style: context.text.labelSmall),
            const SizedBox(height: 8),
            SegmentedPills<FocalMode>(
              options: [for (final m in FocalMode.values) SegmentOption(m, m.label)],
              selected: s.focalMode,
              onChanged: (m) => controller.updateReader((r) => r.copyWith(focalMode: m)),
            ),
            const SizedBox(height: 20),
            Text('THEME', style: context.text.labelSmall),
            const SizedBox(height: 10),
            ReaderThemeSwatches(
              selected: s.themeId,
              onSelected: (id) => controller.updateReader((r) => r.copyWith(themeId: id)),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Natural rhythm'),
              subtitle: Text('Brief pauses at punctuation and long words', style: context.text.bodySmall),
              value: !s.usesStandardTiming,
              onChanged: (v) => controller.updateReader((r) => r.withStandardTiming(!v)),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show context when paused'),
              value: s.showContextWhenPaused,
              onChanged: (v) => controller.updateReader((r) => r.copyWith(showContextWhenPaused: v)),
            ),
          ],
        ),
      ),
    );
  }
}

class FontScaleSlider extends StatelessWidget {
  const FontScaleSlider({required this.value, required this.onChanged, super.key});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('A', style: context.text.titleSmall),
        Expanded(
          child: Slider(
            value: value,
            min: ReaderConstants.minFontScale,
            max: ReaderConstants.maxFontScale,
            divisions: 9,
            semanticFormatterCallback: (v) => 'Word size ${(v * 100).round()}%',
            onChanged: onChanged,
          ),
        ),
        Text('A', style: context.text.headlineMedium),
      ],
    );
  }
}

class ReaderThemeSwatches extends StatelessWidget {
  const ReaderThemeSwatches({required this.selected, required this.onSelected, super.key});

  final ReaderThemeId selected;
  final ValueChanged<ReaderThemeId> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        for (final theme in ReaderTheme.all)
          Expanded(
            child: Semantics(
              button: true,
              selected: selected == theme.id,
              label: '${theme.name} theme',
              child: GestureDetector(
                onTap: () => onSelected(theme.id),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: MotionConstants.fast,
                      height: 52,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: theme.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected == theme.id ? c.accent : c.border,
                          width: selected == theme.id ? 2 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: 'w', style: TextStyle(color: theme.word)),
                          TextSpan(text: 'o', style: TextStyle(color: theme.focal)),
                          TextSpan(text: 'rd', style: TextStyle(color: theme.word)),
                        ]),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(theme.name, style: context.text.bodySmall),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
