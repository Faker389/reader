import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/sanitize.dart';
import '../../../data/providers.dart';
import '../../../domain/models/user_profile.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/settings_tiles.dart';
import '../../../widgets/states.dart';
import '../application/account_service.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final user = ref.watch(currentUserProvider);
    final auth = ref.watch(authRepositoryProvider);
    final provider = user?.provider;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SettingsSection(
                title: 'Profile',
                children: [
                  SettingsTile(
                    icon: Icons.badge_outlined,
                    title: 'Name',
                    value: profile?.name,
                    onTap: profile == null ? null : () => _rename(context, ref, profile.name),
                  ),
                  SettingsTile(icon: Icons.alternate_email_rounded, title: 'Email', value: user?.email),
                  SettingsTile(
                    icon: Icons.key_rounded,
                    title: 'Sign-in method',
                    value: switch (provider) {
                      AuthProviderKind.google => 'Google',
                      AuthProviderKind.local => 'This device',
                      _ => 'Email & password',
                    },
                  ),
                ],
              ),
              if (provider == AuthProviderKind.password && !auth.isLocalMode)
                SettingsSection(
                  title: 'Security',
                  children: [
                    SettingsTile(
                      icon: Icons.lock_reset_rounded,
                      title: 'Change password',
                      subtitle: "We'll email you a secure link.",
                      onTap: () => _resetPassword(context, ref, user!.email),
                    ),
                  ],
                ),
              SettingsSection(
                title: 'Danger zone',
                footer: 'Deleting your account permanently removes your profile, reading history, '
                    'achievements and every book stored for you, on this device and in the cloud. '
                    'This cannot be undone.',
                children: [
                  SettingsTile(
                    icon: Icons.delete_forever_outlined,
                    title: 'Delete account',
                    destructive: true,
                    onTap: () => _delete(context, ref, provider),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, String current) async {
    final controller = TextEditingController(text: current);
    final formKey = GlobalKey<FormState>();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your name'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            validator: Sanitize.validateName,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) Navigator.pop(context, controller.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    try {
      await ref.read(profileRepositoryProvider).setName(name);
      await ref.read(authRepositoryProvider).updateDisplayName(name);
    } on Object catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }

  Future<void> _resetPassword(BuildContext context, WidgetRef ref, String email) async {
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (context.mounted) showAppSnackBar(context, 'Check $email for a link to set a new password.');
    } on Object catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, AuthProviderKind? provider) async {
    final needsPassword = provider != AuthProviderKind.google;
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeleteDialog(needsPassword: needsPassword),
    );
    if (password == null || !context.mounted) return;
    final service = ref.read(accountServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(canPop: false, child: Center(child: CircularProgressIndicator())),
    );
    try {
      await service.deleteAccount(password: needsPassword ? password : null);
      // Signing out redirects away from this screen; the snack bar survives.
      messenger.showSnackBar(const SnackBar(content: Text('Your account and data have been deleted.')));
    } on Object catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        showFailure(context, e);
      }
    }
  }
}

class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog({required this.needsPassword});

  final bool needsPassword;

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _valid =>
      _confirm.text.trim().toUpperCase() == 'DELETE' && (!widget.needsPassword || _password.text.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      title: const Text('Delete your account?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Everything will be permanently erased. Type DELETE to confirm.'),
            const SizedBox(height: 16),
            TextField(
              controller: _confirm,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'DELETE'),
              onChanged: (_) => setState(() {}),
            ),
            if (widget.needsPassword) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Your password'),
                onChanged: (_) => setState(() {}),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text("You'll be asked to confirm with Google.", style: context.text.bodySmall),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: _valid ? () => Navigator.pop(context, _password.text) : null,
          style: TextButton.styleFrom(foregroundColor: c.danger),
          child: const Text('Delete forever'),
        ),
      ],
    );
  }
}
