import 'package:flutter/material.dart';

/// Brand palette exposed as a [ThemeExtension] so widgets read semantic
/// colours (`context.colors.card`) rather than hard-coded values.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.card,
    required this.surface,
    required this.border,
    required this.accent,
    required this.accentSecondary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.text,
    required this.muted,
    required this.subtle,
    required this.onAccent,
  });

  final Color background;
  final Color card;
  final Color surface;
  final Color border;
  final Color accent;
  final Color accentSecondary;
  final Color success;
  final Color warning;
  final Color danger;
  final Color text;
  final Color muted;
  final Color subtle;
  final Color onAccent;

  static const AppColors dark = AppColors(
    background: Color(0xFF08090D),
    card: Color(0xFF12141A),
    surface: Color(0xFF191C24),
    border: Color(0xFF232733),
    accent: Color(0xFF8B5CF6),
    accentSecondary: Color(0xFFEC4899),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFF43F5E),
    text: Color(0xFFF8FAFC),
    muted: Color(0xFF94A3B8),
    subtle: Color(0xFF5B6475),
    onAccent: Color(0xFFFFFFFF),
  );

  static const AppColors darkHighContrast = AppColors(
    background: Color(0xFF000000),
    card: Color(0xFF0E0F14),
    surface: Color(0xFF1A1D26),
    border: Color(0xFF6B7280),
    accent: Color(0xFFA78BFA),
    accentSecondary: Color(0xFFF472B6),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFFB7185),
    text: Color(0xFFFFFFFF),
    muted: Color(0xFFD1D5DB),
    subtle: Color(0xFF9CA3AF),
    onAccent: Color(0xFF000000),
  );

  static const AppColors light = AppColors(
    background: Color(0xFFF6F5F2),
    card: Color(0xFFFFFFFF),
    surface: Color(0xFFEEEDF2),
    border: Color(0xFFE2E1E8),
    accent: Color(0xFF7C3AED),
    accentSecondary: Color(0xFFDB2777),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    danger: Color(0xFFE11D48),
    text: Color(0xFF0B0C10),
    muted: Color(0xFF5B6474),
    subtle: Color(0xFF9AA1AE),
    onAccent: Color(0xFFFFFFFF),
  );

  static const AppColors lightHighContrast = AppColors(
    background: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    surface: Color(0xFFE5E5EA),
    border: Color(0xFF4B5563),
    accent: Color(0xFF5B21B6),
    accentSecondary: Color(0xFF9D174D),
    success: Color(0xFF166534),
    warning: Color(0xFF92400E),
    danger: Color(0xFF9F1239),
    text: Color(0xFF000000),
    muted: Color(0xFF1F2937),
    subtle: Color(0xFF4B5563),
    onAccent: Color(0xFFFFFFFF),
  );

  LinearGradient get accentGradient => LinearGradient(
        colors: [accent, accentSecondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  @override
  AppColors copyWith({
    Color? background,
    Color? card,
    Color? surface,
    Color? border,
    Color? accent,
    Color? accentSecondary,
    Color? success,
    Color? warning,
    Color? danger,
    Color? text,
    Color? muted,
    Color? subtle,
    Color? onAccent,
  }) =>
      AppColors(
        background: background ?? this.background,
        card: card ?? this.card,
        surface: surface ?? this.surface,
        border: border ?? this.border,
        accent: accent ?? this.accent,
        accentSecondary: accentSecondary ?? this.accentSecondary,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
        text: text ?? this.text,
        muted: muted ?? this.muted,
        subtle: subtle ?? this.subtle,
        onAccent: onAccent ?? this.onAccent,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSecondary: Color.lerp(accentSecondary, other.accentSecondary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.dark;
  TextTheme get text => Theme.of(this).textTheme;
}
