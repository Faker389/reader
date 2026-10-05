import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/importers/importer_registry.dart';
import '../../../data/providers.dart';
import '../../../routing/routes.dart';
import '../../../services/reminder_scheduler.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/settings_tiles.dart';
import '../../../widgets/states.dart';
import '../../home/presentation/main_shell.dart';
import '../../settings/application/settings_controller.dart';
import '../../statistics/application/stats_providers.dart';
import '../application/account_service.dart';
import 'user_avatar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final stats = ref.watch(readingStatsProvider);
    final goal = ref.watch(goalMinutesProvider);
    final settings = ref.watch(settingsControllerProvider);
    final localMode = ref.watch(authRepositoryProvider).isLocalMode;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: LayoutConstants.maxContentWidth),
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, shellBottomInset(context)),
              children: [
                Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Change profile photo',
                      child: GestureDetector(
                        onTap: () => _changeAvatar(context, ref),
                        child: Stack(
                          children: [
                            UserAvatar(profile: profile, size: 76),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: context.colors.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: context.colors.background, width: 2),
                                ),
                                child: Icon(Icons.edit_rounded, size: 12, color: context.colors.text),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile?.name ?? '', style: context.text.headlineSmall),
                          const SizedBox(height: 2),
                          Text(profile?.email ?? '', style: context.text.bodyMedium),
                          if (profile != null)
                            Text(
                              'Reading since ${Formatters.shortDate(profile.createdAt)}, ${profile.createdAt.year}',
                              style: context.text.bodySmall?.copyWith(color: context.colors.subtle),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                  child: Row(
                    children: [
                      _MiniStat(value: Formatters.compact(stats.totalWords), label: 'Words'),
                      _MiniStat(value: Formatters.duration(Duration(seconds: stats.totalSeconds)), label: 'Time'),
                      _MiniStat(value: '${stats.booksCompleted}', label: 'Books'),
                      _MiniStat(value: '${stats.streak.current}', label: 'Streak'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SettingsSection(
                  title: 'Reading',
                  children: [
                    SettingsTile(
                      icon: Icons.flag_outlined,
                      title: 'Daily goal',
                      value: '$goal min',
                      onTap: () => _pickGoal(context, ref, goal),
                    ),
                    SettingsTile(
                      icon: Icons.tune_rounded,
                      title: 'Reader settings',
                      value: '${settings.reader.defaultWpm} WPM',
                      onTap: () => context.push(Routes.readerSettings),
                    ),
                    SettingsTile(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications',
                      value: settings.notifications.enabled ? 'On' : 'Off',
                      onTap: () => context.push(Routes.notificationSettings),
                    ),
                    SettingsTile(
                      icon: Icons.palette_outlined,
                      title: 'Appearance',
                      value: settings.theme.label,
                      onTap: () => context.push(Routes.appearanceSettings),
                    ),
                  ],
                ),
                SettingsSection(
                  title: 'Account',
                  footer: localMode ? 'Device-only mode: your data stays on this device.' : null,
                  children: [
                    SettingsTile(
                      icon: Icons.person_outline_rounded,
                      title: 'Account',
                      onTap: () => context.push(Routes.accountSettings),
                    ),
                    SettingsTile(
                      icon: Icons.shield_outlined,
                      title: 'Privacy',
                      onTap: () => context.push(Routes.privacy),
                    ),
                  ],
                ),
                SettingsSection(
                  title: 'About',
                  children: [
                    SettingsTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Help',
                      onTap: () => context.push(Routes.info(InfoPage.help)),
                    ),
                    SettingsTile(
                      icon: Icons.description_outlined,
                      title: 'Terms',
                      onTap: () => context.push(Routes.info(InfoPage.terms)),
                    ),
                    SettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy policy',
                      onTap: () => context.push(Routes.info(InfoPage.privacyPolicy)),
                    ),
                  ],
                ),
                SettingsSection(
                  children: [
                    SettingsTile(
                      icon: Icons.logout_rounded,
                      title: 'Log out',
                      onTap: () => _confirmSignOut(context, ref),
                    ),
                    SettingsTile(
                      icon: Icons.delete_outline_rounded,
                      title: 'Delete account',
                      destructive: true,
                      onTap: () => context.push(Routes.accountSettings),
                    ),
                  ],
                ),
                Center(
                  child: Text('${AppInfo.name} · ${AppInfo.tagline}', style: context.text.bodySmall),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changeAvatar(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.image, withData: true);
      final file = result?.files.firstOrNull;
      final bytes = file?.bytes;
      if (file == null || bytes == null) return;
      if (bytes.length > 5 * 1024 * 1024) {
        if (context.mounted) showAppSnackBar(context, 'Choose an image under 5 MB.', error: true);
        return;
      }
      final ext = ImporterRegistry.extensionOf(file.name) == 'png' ? 'png' : 'jpg';
      await ref.read(profileRepositoryProvider).setAvatar(bytes, ext);
    } on Object catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }

  Future<void> _pickGoal(BuildContext context, WidgetRef ref, int current) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Text('Daily reading goal', style: context.text.titleLarge),
            ),
            for (final m in GoalConstants.dailyMinuteOptions)
              ListTile(
                title: Text('$m minutes'),
                trailing: m == current ? Icon(Icons.check_rounded, color: context.colors.accent) : null,
                onTap: () => Navigator.pop(context, m),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == null || selected == current) return;
    await ref.read(profileRepositoryProvider).setGoal(selected);
    await ref.read(reminderSchedulerProvider).reschedule();
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Your books and progress stay saved on this device for when you return.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(accountServiceProvider).signOut();
    } on Object catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: context.text.titleLarge)),
            const SizedBox(height: 2),
            Text(label, style: context.text.bodySmall),
          ],
        ),
      );
}