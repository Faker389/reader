import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_card.dart';
import '../../onboarding/presentation/splash_screen.dart';

class AuthLayout extends ConsumerWidget {
  const AuthLayout({
    required this.title,
    required this.subtitle,
    required this.children,
    this.showBack = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localMode = ref.watch(authRepositoryProvider).isLocalMode;
    return Scaffold(
      appBar: showBack ? AppBar() : null,
      body: Stack(
        children: [
          const Positioned(top: -160, right: -120, child: AccentGlow(size: 420, opacity: 0.16)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!showBack) ...[
                          const Align(alignment: Alignment.centerLeft, child: FoveaMark(size: 44)),
                          const SizedBox(height: 28),
                        ],
                        Text(title, style: context.text.displaySmall),
                        const SizedBox(height: 8),
                        Text(subtitle, style: context.text.bodyMedium),
                        if (localMode) ...[
                          const SizedBox(height: 20),
                          const _OfflineBanner(),
                        ],
                        const SizedBox(height: 28),
                        ...children,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(14),
      color: c.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.phone_android_rounded, size: 20, color: c.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Device-only mode: your account and reading data stay on this device. '
              'Cloud sync turns on once the app is connected to Firebase.',
              style: context.text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Text field with consistent spacing for auth forms.
class AuthField extends StatefulWidget {
  const AuthField({
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
    this.autofillHints,
    this.obscure = false,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final bool obscure;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: widget.controller,
        validator: widget.validator,
        keyboardType: widget.keyboardType,
        autofillHints: widget.autofillHints,
        obscureText: _hidden,
        autocorrect: false,
        enableSuggestions: !widget.obscure,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          labelText: widget.label,
          suffixIcon: widget.obscure
              ? IconButton(
                  tooltip: _hidden ? 'Show password' : 'Hide password',
                  icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _hidden = !_hidden),
                )
              : null,
        ),
      ),
    );
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('or', style: context.text.bodySmall),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
