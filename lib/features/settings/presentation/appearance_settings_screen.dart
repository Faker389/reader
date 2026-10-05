import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/app_settings.dart';
import '../../../widgets/segmented.dart';
import '../../../widgets/settings_tiles.dart';
import '../application/settings_controller.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SettingsSection(
                title: 'Theme',
                footer: 'The reading screen has its own themes, found in Reader settings.',
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SegmentedPills<AppThemePreference>(
                      options: [for (final t in AppThemePreference.values) SegmentOption(t, t.label)],
                      selected: s.theme,
                      onChanged: (t) => controller.update((a) => a.copyWith(theme: t)),
                    ),
                  ),
                ],
              ),
              SettingsSection(
                title: 'Accessibility',
                children: [
                  SettingsSwitch(
                    icon: Icons.text_increase_rounded,
                    title: 'Larger text',
                    subtitle: 'Increase text size throughout the app',
                    value: s.largeText,
                    onChanged: (v) => controller.update((a) => a.copyWith(largeText: v)),
                  ),
                  SettingsSwitch(
                    icon: Icons.contrast_rounded,
                    title: 'High contrast',
                    subtitle: 'Stronger borders and brighter text',
                    value: s.highContrast,
                    onChanged: (v) => controller.update((a) => a.copyWith(highContrast: v)),
                  ),
                  SettingsSwitch(
                    icon: Icons.animation_rounded,
                    title: 'Reduce motion',
                    subtitle: 'Minimise animations and transitions',
                    value: s.reduceMotion,
                    onChanged: (v) => controller.update((a) => a.copyWith(reduceMotion: v)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
