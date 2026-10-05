import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/models/reader_settings.dart';

/// Editorial serif for display moments, a clean geometric sans for UI.
/// TODO(release): bundle the font files under assets/google_fonts/ and set
/// `GoogleFonts.config.allowRuntimeFetching = false` so typography is
/// identical on first launch offline.
abstract final class AppTypography {
  static TextTheme textTheme(Color text, Color muted) {
    final base = GoogleFonts.manropeTextTheme();
    TextStyle display(double size, {FontWeight weight = FontWeight.w500, double height = 1.1}) =>
        GoogleFonts.fraunces(
          fontSize: size,
          fontWeight: weight,
          height: height,
          letterSpacing: -0.5,
          color: text,
        );
    TextStyle ui(double size, FontWeight weight, {Color? color, double? spacing, double height = 1.35}) =>
        GoogleFonts.manrope(
          fontSize: size,
          fontWeight: weight,
          color: color ?? text,
          letterSpacing: spacing,
          height: height,
        );

    return base.copyWith(
      displayLarge: display(52, weight: FontWeight.w600),
      displayMedium: display(40, weight: FontWeight.w600),
      displaySmall: display(32),
      headlineLarge: display(30),
      headlineMedium: display(26),
      headlineSmall: display(22),
      titleLarge: ui(20, FontWeight.w700, spacing: -0.3),
      titleMedium: ui(16, FontWeight.w700, spacing: -0.1),
      titleSmall: ui(14, FontWeight.w700),
      bodyLarge: ui(16, FontWeight.w500, height: 1.5),
      bodyMedium: ui(14, FontWeight.w500, color: muted, height: 1.45),
      bodySmall: ui(12, FontWeight.w500, color: muted),
      labelLarge: ui(15, FontWeight.w700, spacing: 0.1),
      labelMedium: ui(12, FontWeight.w700, color: muted, spacing: 0.4),
      labelSmall: ui(11, FontWeight.w800, color: muted, spacing: 1.2),
    );
  }

  /// Fonts for the RSVP word. Chosen for clear letterforms at large sizes.
  static TextStyle readerStyle(ReaderFont font, {required double size, required FontWeight weight}) {
    return switch (font) {
      ReaderFont.sans => GoogleFonts.inter(fontSize: size, fontWeight: weight, height: 1),
      ReaderFont.serif => GoogleFonts.literata(fontSize: size, fontWeight: weight, height: 1),
      ReaderFont.mono => GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: weight, height: 1),
    };
  }

  static TextStyle numeric(TextStyle style) =>
      style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
