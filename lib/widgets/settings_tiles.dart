import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_card.dart';

/// Grouped card of settings rows with an optional caption above it.
class SettingsSection extends StatelessWidget {
  const SettingsSection({required this.children, this.title, this.footer, super.key});

  final String? title;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text(title!.toUpperCase(), style: context.text.labelSmall),
            ),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) Divider(height: 0.5, thickness: 0.5, indent: 56, color: c.border.withValues(alpha: 0.6)),
                  children[i],
                ],
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(footer!, style: context.text.bodySmall),
            ),
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.title,
    this.icon,
    this.subtitle,
    this.value,
    this.onTap,
    this.trailing,
    this.destructive = false,
    super.key,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = destructive ? c.danger : c.text;
    return ListTile(
      onTap: onTap,
      leading: icon == null ? null : Icon(icon, color: destructive ? c.danger : c.muted, size: 22),
      title: Text(title, style: context.text.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: context.text.bodySmall),
      trailing: trailing ??
          (value != null || onTap != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (value != null) Text(value!, style: context.text.bodyMedium),
                    if (onTap != null && !destructive) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, color: c.subtle),
                    ],
                  ],
                )
              : null),
    );
  }
}

class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
    this.icon,
    this.subtitle,
    super.key,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      secondary: icon == null ? null : Icon(icon, color: c.muted, size: 22),
      title: Text(title, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: context.text.bodySmall),
    );
  }
}

/// Labelled slider row for multipliers and sizes.
class SettingsSlider extends StatelessWidget {
  const SettingsSlider({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
    this.divisions,
    this.enabled = true,
    super.key,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String label;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: enabled ? null : context.colors.subtle,
                  ),
                ),
              ),
              Text(label, style: context.text.labelLarge?.copyWith(color: context.colors.accent)),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: label,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
