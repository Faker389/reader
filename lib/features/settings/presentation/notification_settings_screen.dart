import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../domain/models/app_settings.dart';
import '../../../services/reminder_scheduler.dart';
import '../../../widgets/settings_tiles.dart';
import '../../../widgets/states.dart';
import '../application/settings_controller.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  Future<void> _update(WidgetRef ref, NotificationPreferences Function(NotificationPreferences) change) async {
    await ref.read(settingsControllerProvider.notifier).updateNotifications(change);
    await ref.read(reminderSchedulerProvider).reschedule();
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool enabled) async {
    if (enabled) {
      final granted = await ref.read(notificationServiceProvider).requestPermission();
      if (!granted) {
        if (context.mounted) {
          showAppSnackBar(
            context,
            'Notifications are blocked. You can allow them in your device settings.',
            error: true,
          );
        }
        return;
      }
    }
    await _update(ref, (n) => n.copyWith(enabled: enabled));
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref, NotificationPreferences prefs) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: prefs.hour, minute: prefs.minute),
      helpText: 'Reminder time',
    );
    if (time == null) return;
    await _update(ref, (n) => n.copyWith(hour: time.hour, minute: time.minute));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(settingsControllerProvider.select((s) => s.notifications));
    final time = TimeOfDay(hour: prefs.hour, minute: prefs.minute);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SettingsSection(
                footer: 'At most one gentle reminder a day, and none once you have met your goal.',
                children: [
                  SettingsSwitch(
                    icon: Icons.notifications_none_rounded,
                    title: 'Daily reminder',
                    value: prefs.enabled,
                    onChanged: (v) => _toggle(context, ref, v),
                  ),
                  if (prefs.enabled)
                    SettingsTile(
                      icon: Icons.schedule_rounded,
                      title: 'Time',
                      value: time.format(context),
                      onTap: () => _pickTime(context, ref, prefs),
                    ),
                ],
              ),
              if (prefs.enabled)
                SettingsSection(
                  title: 'Remind me about',
                  children: [
                    SettingsSwitch(
                      title: 'My daily goal',
                      value: prefs.goalReminders,
                      onChanged: (v) => _update(ref, (n) => n.copyWith(goalReminders: v)),
                    ),
                    SettingsSwitch(
                      title: 'Keeping my streak',
                      value: prefs.streakReminders,
                      onChanged: (v) => _update(ref, (n) => n.copyWith(streakReminders: v)),
                    ),
                    SettingsSwitch(
                      title: 'The book I’m reading',
                      value: prefs.continueReminders,
                      onChanged: (v) => _update(ref, (n) => n.copyWith(continueReminders: v)),
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
