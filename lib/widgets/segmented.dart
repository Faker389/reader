import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../theme/app_colors.dart';
import 'motion.dart';

class SegmentOption<T> {
  const SegmentOption(this.value, this.label);

  final T value;
  final String label;
}

/// Pill-shaped segmented control with a sliding selection indicator.
class SegmentedPills<T> extends StatelessWidget {
  const SegmentedPills({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.background,
    this.selectedColor,
    this.textColor,
    this.selectedTextColor,
    super.key,
  });

  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final Color? background;
  final Color? selectedColor;
  final Color? textColor;
  final Color? selectedTextColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final index = options.indexWhere((o) => o.value == selected).clamp(0, options.length - 1);
    return LayoutBuilder(builder: (context, constraints) {
      final segmentWidth = (constraints.maxWidth - 8) / options.length;
      return Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: background ?? c.surface, borderRadius: BorderRadius.circular(22)),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: context.motion(MotionConstants.medium),
              curve: Curves.easeOutCubic,
              left: segmentWidth * index,
              top: 0,
              bottom: 0,
              width: segmentWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selectedColor ?? c.card,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8)],
                ),
              ),
            ),
            Row(
              children: [
                for (final option in options)
                  Expanded(
                    child: Semantics(
                      selected: option.value == selected,
                      button: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(option.value),
                        child: Center(
                          child: Text(
                            option.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelLarge?.copyWith(
                              fontSize: 13,
                              color: option.value == selected
                                  ? (selectedTextColor ?? c.text)
                                  : (textColor ?? c.muted),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }
}
