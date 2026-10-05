import 'package:flutter/material.dart';

import '../domain/models/reader_settings.dart';

/// Colour schemes for the reading screen only. Deliberately calm: no
/// gradients, low-contrast chrome, high-contrast word.
class ReaderTheme {
  const ReaderTheme({
    required this.id,
    required this.name,
    required this.background,
    required this.word,
    required this.focal,
    required this.chrome,
    required this.chromeMuted,
    required this.guide,
    required this.isDark,
  });

  final ReaderThemeId id;
  final String name;
  final Color background;
  final Color word;
  final Color focal;
  final Color chrome;
  final Color chromeMuted;
  final Color guide;
  final bool isDark;

  static const List<ReaderTheme> all = [
    ReaderTheme(
      id: ReaderThemeId.midnight,
      name: 'Midnight',
      background: Color(0xFF08090D),
      word: Color(0xFFF8FAFC),
      focal: Color(0xFFEC4899),
      chrome: Color(0xFFE2E8F0),
      chromeMuted: Color(0xFF64748B),
      guide: Color(0xFF2A2E3A),
      isDark: true,
    ),
    ReaderTheme(
      id: ReaderThemeId.graphite,
      name: 'Graphite',
      background: Color(0xFF1B1D22),
      word: Color(0xFFE9E9EC),
      focal: Color(0xFFA78BFA),
      chrome: Color(0xFFD4D4D8),
      chromeMuted: Color(0xFF71717A),
      guide: Color(0xFF34363D),
      isDark: true,
    ),
    ReaderTheme(
      id: ReaderThemeId.sepia,
      name: 'Sepia',
      background: Color(0xFFF3E9D7),
      word: Color(0xFF3B2F25),
      focal: Color(0xFFB4532A),
      chrome: Color(0xFF5C4A3A),
      chromeMuted: Color(0xFF9C8771),
      guide: Color(0xFFDCCDB4),
      isDark: false,
    ),
    ReaderTheme(
      id: ReaderThemeId.paper,
      name: 'Paper',
      background: Color(0xFFFAFAF7),
      word: Color(0xFF111114),
      focal: Color(0xFF7C3AED),
      chrome: Color(0xFF27272A),
      chromeMuted: Color(0xFF8A8A93),
      guide: Color(0xFFE4E4E7),
      isDark: false,
    ),
  ];

  static ReaderTheme of(ReaderThemeId id) => all.firstWhere((t) => t.id == id, orElse: () => all.first);
}
