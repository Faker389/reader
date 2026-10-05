import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/sanitize.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/states.dart';
import '../application/auth_controller.dart';
import 'auth_layout.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    try {
      await ref.read(authControllerProvider.notifier).sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } on Object catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  void _back() => context.canPop() ? context.pop() : context.go(Routes.signIn);

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider);
    if (_sent) {
      return AuthLayout(
        showBack: true,
        title: 'Check your inbox.',
        subtitle: 'If an account exists for ${_email.text.trim()}, a reset link is on its way. '
            "It can take a minute — don't forget your spam folder.",
        children: [PrimaryButton(label: 'Back to sign in', onPressed: _back)],
      );
    }
    return AuthLayout(
      showBack: true,
      title: 'Reset your password.',
      subtitle: "Enter your account email and we'll send you a link to choose a new password.",
      children: [
        Form(
          key: _form,
          child: AuthField(
            controller: _email,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            validator: Sanitize.validateEmail,
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(height: 8),
        PrimaryButton(label: 'Send reset link', loading: busy, onPressed: _submit),
        const SizedBox(height: 12),
        Center(
          child: TextButton(onPressed: _back, child: Text('Back to sign in', style: context.text.labelLarge)),
        ),
      ],
    );
  }
}
