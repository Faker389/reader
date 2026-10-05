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

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    try {
      await ref.read(authControllerProvider.notifier).signIn(_email.text, _password.text);
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
    final busy = ref.watch(authControllerProvider);
    final supportsGoogle = ref.watch(authRepositoryProvider).supportsGoogle;
    return AuthLayout(
      title: 'Welcome back.',
      subtitle: 'Sign in to pick up exactly where you left off.',
      children: [
        Form(
          key: _form,
          child: Column(
            children: [
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
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                validator: (v) => (v ?? '').isEmpty ? 'Enter your password' : null,
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.push(Routes.forgotPassword),
            child: const Text('Forgot password?'),
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(label: 'Sign in', loading: busy, onPressed: _submit),
        if (supportsGoogle) ...[
          const OrDivider(),
          SecondaryButton(
            label: 'Continue with Google',
            icon: Icons.g_mobiledata_rounded,
            onPressed: busy ? null : _google,
          ),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('New to Fovea?', style: context.text.bodyMedium),
            TextButton(onPressed: () => context.go(Routes.signUp), child: const Text('Create an account')),
          ],
        ),
      ],
    );
  }
}
