import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';
import '../../../widgets/settings_tiles.dart';
import '../application/settings_controller.dart';

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(settingsControllerProvider.select((s) => s.analyticsEnabled));
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SettingsSection(
                footer: 'Anonymous events such as "session completed" help us improve Fovea. '
                    'They never include book titles, book text or your name.',
                children: [
                  SettingsSwitch(
                    icon: Icons.analytics_outlined,
                    title: 'Share usage analytics',
                    value: analytics,
                    onChanged: (v) => ref.read(settingsControllerProvider.notifier).setAnalyticsEnabled(v),
                  ),
                ],
              ),
              SettingsSection(
                title: 'Your books',
                footer: 'Imported book text is stored only on this device. Titles, authors and reading '
                    'progress sync to your private account so your library follows you.',
                children: [
                  SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy policy',
                    onTap: () => context.push(Routes.info(InfoPage.privacyPolicy)),
                  ),
                  SettingsTile(
                    icon: Icons.manage_accounts_outlined,
                    title: 'Delete my data',
                    onTap: () => context.push(Routes.accountSettings),
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
