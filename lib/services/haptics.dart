import 'package:flutter/services.dart';

/// Thin wrapper so haptics can be disabled globally from settings and are
/// used consistently (light for steps, medium for play/pause).
class Haptics {
  const Haptics({required this.enabled});

  final bool enabled;

  void selection() {
    if (enabled) HapticFeedback.selectionClick();
  }

  void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }
}
