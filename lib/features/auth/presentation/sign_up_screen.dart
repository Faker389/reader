import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/sanitize.dart';
import '../../../data/providers.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/states.dart';
import '../application/auth_controller.dart';
import 'auth_layout.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()
    ..onTap = () => context.push(Routes.info(InfoPage.terms));
  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()
    ..onTap = () => context.push(Routes.info(InfoPage.privacyPolicy));

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    try {
      await ref.read(authControllerProvider.notifier).signUp(_name.text, _email.text, _password.text);
    } on Object catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  Future<void> _google() async {
    try {
      await ref.read(authControllerProvider.notifier).signInWithGoogle();
    } on Object catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final busy = ref.watch(authControllerProvider);
    final supportsGoogle = ref.watch(authRepositoryProvider).supportsGoogle;
    return AuthLayout(
      title: 'Create your account.',
      subtitle: 'Save your progress, streaks and library.',
      children: [
        if (supportsGoogle) ...[
          SecondaryButton(
            label: 'Continue with Google',
            icon: Icons.g_mobiledata_rounded,
            onPressed: busy ? null : _google,
          ),
          const OrDivider(),
        ],
        Form(
          key: _form,
          child: Column(
            children: [
              AuthField(
                controller: _name,
                label: 'Name',
                keyboardType: TextInputType.name,
                autofillHints: const [AutofillHints.givenName],
                validator: Sanitize.validateName,
              ),
              AuthField(
                controller: _email,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: Sanitize.validateEmail,
              ),
              AuthField(
                controller: _password,
                label: 'Password',
                obscure: true,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                validator: Sanitize.validatePassword,
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        PrimaryButton(label: 'Create account', loading: busy, onPressed: _submit),
        const SizedBox(height: 16),
        Text.rich(
          TextSpan(
            style: context.text.bodySmall,
            children: [
              const TextSpan(text: 'By continuing you agree to the '),
              TextSpan(text: 'Terms', style: TextStyle(color: c.accent), recognizer: _termsTap),
              const TextSpan(text: ' and '),
              TextSpan(text: 'Privacy Policy', style: TextStyle(color: c.accent), recognizer: _privacyTap),
              const TextSpan(text: '.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Already have an account?', style: context.text.bodyMedium),
            TextButton(onPressed: () => context.go(Routes.signIn), child: const Text('Sign in')),
          ],
        ),
      ],
    );
  }
}
