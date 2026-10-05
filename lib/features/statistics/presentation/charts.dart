import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/stats/period_stats.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/motion.dart';

/// Lightweight animated charts drawn with [CustomPainter], so no chart
/// dependency is needed and they match the app's visual language.
class BarChart extends StatelessWidget {
  const BarChart({required this.points, this.height = 160, this.highlightLast = true, super.key});

  final List<ChartPoint> points;
  final double height;
  final bool highlightLast;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _AnimatedChart(
      height: height,
      points: points,
      builder: (t) => _BarPainter(
        points: points,
        t: t,
        gradient: [c.accent, c.accentSecondary],
        muted: c.accent.withValues(alpha: 0.35),
        track: c.surface,
        label: context.text.labelMedium!.copyWith(fontSize: 10, letterSpacing: 0),
        highlightLast: highlightLast,
      ),
    );
  }
}

class LineChart extends StatelessWidget {
  const LineChart({required this.points, this.height = 160, super.key});

  final List<ChartPoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _AnimatedChart(
      height: height,
      points: points,
      builder: (t) => _LinePainter(
        points: points,
        t: t,
        line: c.accent,
        fill: c.accent.withValues(alpha: 0.16),
        grid: c.border.withValues(alpha: 0.5),
        dot: c.accentSecondary,
        label: context.text.labelMedium!.copyWith(fontSize: 10, letterSpacing: 0),
      ),
    );
  }
}

class _AnimatedChart extends StatelessWidget {
  const _AnimatedChart({required this.height, required this.points, required this.builder});

  final double height;
  final List<ChartPoint> points;
  final CustomPainter Function(double t) builder;

  @override
  Widget build(BuildContext context) {
    final summary = points.where((p) => p.value > 0).map((p) => '${p.label} ${p.value.round()}').join(', ');
    return Semantics(
      label: summary.isEmpty ? 'No data yet' : summary,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(Object.hashAll(points.map((p) => p.value))),
        tween: Tween(begin: 0, end: 1),
        duration: context.motion(MotionConstants.slow),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(painter: builder(t)),
        ),
      ),
    );
  }
}

const double _labelSpace = 18;

void _drawLabels(Canvas canvas, Size size, List<ChartPoint> points, TextStyle style, double Function(int) xOf) {
  for (var i = 0; i < points.length; i++) {
    final label = points[i].label;
    if (label.isEmpty) continue;
    final tp = TextPainter(text: TextSpan(text: label, style: style), textDirection: TextDirection.ltr)..layout();
    final x = (xOf(i) - tp.width / 2).clamp(0.0, size.width - tp.width);
    tp.paint(canvas, Offset(x, size.height - tp.height));
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.points,
    required this.t,
    required this.gradient,
    required this.muted,
    required this.track,
    required this.label,
    required this.highlightLast,
  });

  final List<ChartPoint> points;
  final double t;
  final List<Color> gradient;
  final Color muted;
  final Color track;
  final TextStyle label;
  final bool highlightLast;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final chartHeight = size.height - _labelSpace;
    final maxValue = points.map((p) => p.value).fold<double>(0, math.max);
    final slot = size.width / points.length;
    final barWidth = math.min(28.0, slot * 0.62);
    double xOf(int i) => slot * i + slot / 2;

    for (var i = 0; i < points.length; i++) {
      final x = xOf(i) - barWidth / 2;
      final trackRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, barWidth, chartHeight),
        Radius.circular(barWidth / 2.5),
      );
      canvas.drawRRect(trackRect, Paint()..color = track.withValues(alpha: 0.5));
      if (maxValue <= 0 || points[i].value <= 0) continue;
      final h = math.max(barWidth * 0.6, chartHeight * (points[i].value / maxValue) * t);
      final rect = Rect.fromLTWH(x, chartHeight - h, barWidth, h);
      final isHighlight = highlightLast ? i == points.length - 1 : true;
      final paint = Paint();
      if (isHighlight) {
        paint.shader = LinearGradient(
          colors: gradient,
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ).createShader(rect);
      } else {
        paint.color = muted;
      }
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(barWidth / 2.5)), paint);
    }
    _drawLabels(canvas, size, points, label, xOf);
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.t != t || old.points != points || old.gradient != gradient;
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.points,
    required this.t,
    required this.line,
    required this.fill,
    required this.grid,
    required this.dot,
    required this.label,
  });

  final List<ChartPoint> points;
  final double t;
  final Color line;
  final Color fill;
  final Color grid;
  final Color dot;
  final TextStyle label;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final chartHeight = size.height - _labelSpace - 8;
    final values = points.map((p) => p.value).toList();
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final range = math.max(1.0, maxV - minV);
    final lo = math.max(0.0, minV - range * 0.25);
    final hi = maxV + range * 0.25;
    double xOf(int i) => points.length == 1 ? size.width / 2 : 8 + (size.width - 16) * i / (points.length - 1);
    double yOf(double v) => 4 + chartHeight * (1 - (v - lo) / (hi - lo));

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 0.5;
    for (var g = 0; g <= 3; g++) {
      final y = 4 + chartHeight * g / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final visibleCount = math.max(1, (points.length * t).ceil());
    final path = Path();
    for (var i = 0; i < visibleCount; i++) {
      final p = Offset(xOf(i), yOf(values[i]));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        final prev = Offset(xOf(i - 1), yOf(values[i - 1]));
        final midX = (prev.dx + p.dx) / 2;
        path.cubicTo(midX, prev.dy, midX, p.dy, p.dx, p.dy);
      }
    }
    if (visibleCount > 1) {
      final area = Path.from(path)
        ..lineTo(xOf(visibleCount - 1), 4 + chartHeight)
        ..lineTo(xOf(0), 4 + chartHeight)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            colors: [fill, fill.withValues(alpha: 0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Offset.zero & size),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    final last = Offset(xOf(visibleCount - 1), yOf(values[visibleCount - 1]));
    canvas.drawCircle(last, 5, Paint()..color = dot);
    canvas.drawCircle(last, 2.5, Paint()..color = Colors.white);

    final valueStyle = label.copyWith(color: line, fontWeight: FontWeight.w800);
    final tp = TextPainter(
      text: TextSpan(text: values[visibleCount - 1].round().toString(), style: valueStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((last.dx - tp.width / 2).clamp(0.0, size.width - tp.width), math.max(0, last.dy - 20)));

    _drawLabels(canvas, size, points, label, xOf);
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.t != t || old.points != points || old.line != line;
}
