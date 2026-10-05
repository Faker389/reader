import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../theme/app_colors.dart';
import 'motion.dart';

/// Circular progress that animates from its previous value (or [from]).
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    required this.value,
    this.from,
    this.size = 120,
    this.strokeWidth = 10,
    this.child,
    this.duration = MotionConstants.slow,
    this.trackColor,
    super.key,
  });

  final double value;
  final double? from;
  final double size;
  final double strokeWidth;
  final Widget? child;
  final Duration duration;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: from ?? 0, end: value.clamp(0.0, 1.0)),
      duration: context.motion(duration),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(
            progress: animated,
            stroke: strokeWidth,
            track: trackColor ?? c.surface,
            gradient: SweepGradient(
              startAngle: -math.pi / 2,
              endAngle: 3 * math.pi / 2,
              colors: [c.accent, c.accentSecondary, c.accent],
              stops: const [0, 0.6, 1],
            ),
            complete: animated >= 1 ? c.success : null,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.stroke,
    required this.track,
    required this.gradient,
    this.complete,
  });

  final double progress;
  final double stroke;
  final Color track;
  final Gradient gradient;
  final Color? complete;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    canvas.drawArc(
      arcRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (progress <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    if (complete != null) {
      paint.color = complete!;
    } else {
      paint.shader = gradient.createShader(rect);
    }
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * progress, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.track != track || old.complete != complete;
}

/// Rounded horizontal progress bar.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    required this.value,
    this.from,
    this.height = 6,
    this.color,
    this.trackColor,
    super.key,
  });

  final double value;
  final double? from;
  final double height;
  final Color? color;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      value: '${(value * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: from ?? value, end: value.clamp(0.0, 1.0)),
            duration: context.motion(MotionConstants.slow),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: trackColor ?? c.surface),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: v,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      gradient: color == null ? c.accentGradient : null,
                      borderRadius: BorderRadius.circular(height),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Integer that counts up to its value.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    required this.value,
    required this.style,
    this.from = 0,
    this.format,
    this.duration = MotionConstants.celebration,
    super.key,
  });

  final int value;
  final int from;
  final TextStyle? style;
  final String Function(int value)? format;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: from.toDouble(), end: value.toDouble()),
      duration: context.motion(duration),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final n = v.round();
        return Text(format?.call(n) ?? '$n', style: style);
      },
    );
  }
}
