import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../domain/models/reader_settings.dart';
import '../../../../domain/reading/focal_point.dart';

/// Visual configuration of the displayed word.
@immutable
class RsvpWordStyle {
  const RsvpWordStyle({
    required this.text,
    required this.wordColor,
    required this.focalColor,
    required this.guideColor,
    required this.focalMode,
    required this.showGuides,
  });

  final TextStyle text;
  final Color wordColor;
  final Color focalColor;
  final Color guideColor;
  final FocalMode focalMode;
  final bool showGuides;

  @override
  bool operator ==(Object other) =>
      other is RsvpWordStyle &&
      other.text == text &&
      other.wordColor == wordColor &&
      other.focalColor == focalColor &&
      other.guideColor == guideColor &&
      other.focalMode == focalMode &&
      other.showGuides == showGuides;

  @override
  int get hashCode => Object.hash(text, wordColor, focalColor, guideColor, focalMode, showGuides);
}

/// Displays exactly one word, anchored so that its focal character sits on
/// a fixed point. The widget never rebuilds while reading: the painter is
/// bound to [position] and only repaints.
class RsvpWordView extends StatelessWidget {
  const RsvpWordView({
    required this.words,
    required this.position,
    required this.style,
    required this.height,
    this.anchor = defaultAnchor,
    super.key,
  });

  /// Horizontal position of the focal character as a fraction of the width.
  /// Slightly left of centre balances words around their recognition point.
  static const double defaultAnchor = 0.44;

  final List<String> words;
  final ValueListenable<int> position;
  final RsvpWordStyle style;
  final double height;
  final double anchor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: false,
      label: 'Reading area',
      child: RepaintBoundary(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: RsvpWordPainter(
              words: words,
              position: position,
              style: style,
              anchor: anchor,
              textScaler: MediaQuery.textScalerOf(context),
            ),
          ),
        ),
      ),
    );
  }
}

class RsvpWordPainter extends CustomPainter {
  RsvpWordPainter({
    required this.words,
    required this.position,
    required this.style,
    required this.anchor,
    required this.textScaler,
  }) : super(repaint: position);

  final List<String> words;
  final ValueListenable<int> position;
  final RsvpWordStyle style;
  final double anchor;
  final TextScaler textScaler;

  static const double _horizontalPadding = 20;
  static const double _guideLength = 9;
  static const double _guideGap = 14;
  static const FontWeight _emphasisWeight = FontWeight.w800;

  // Reused between frames to avoid per-word allocations of painters.
  final TextPainter _prefix = TextPainter(textDirection: TextDirection.ltr, maxLines: 1);
  final TextPainter _focal = TextPainter(textDirection: TextDirection.ltr, maxLines: 1);
  final TextPainter _suffix = TextPainter(textDirection: TextDirection.ltr, maxLines: 1);

  late final TextStyle _base = style.text.copyWith(color: style.wordColor);
  late final TextStyle _focalStyle = switch (style.focalMode) {
    FocalMode.none => _base,
    FocalMode.bold => _base.copyWith(fontWeight: _emphasisWeight),
    FocalMode.accent => _base.copyWith(color: style.focalColor),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final focalX = size.width * anchor;
    final centerY = size.height / 2;

    if (style.showGuides) _paintGuides(canvas, size, focalX);
    if (words.isEmpty) return;

    final index = position.value.clamp(0, words.length - 1);
    final word = words[index];
    final focalIndex = FocalPoint.indexFor(word);
    final focalEnd = focalIndex + FocalPoint.focalLength(word, focalIndex);

    _layout(word, focalIndex, focalEnd, 1);

    final leftRoom = focalX - _horizontalPadding;
    final rightRoom = size.width - focalX - _horizontalPadding;
    final halfFocal = _focal.width / 2;
    final scale = math.min(
      1.0,
      math.min(
        leftRoom / math.max(1, _prefix.width + halfFocal),
        rightRoom / math.max(1, _suffix.width + halfFocal),
      ),
    );
    if (scale < 1) _layout(word, focalIndex, focalEnd, scale);

    final focalLeft = focalX - _focal.width / 2;
    final top = centerY - _focal.height / 2;
    _prefix.paint(canvas, Offset(focalLeft - _prefix.width, top));
    _focal.paint(canvas, Offset(focalLeft, top));
    _suffix.paint(canvas, Offset(focalLeft + _focal.width, top));
  }

  void _layout(String word, int focalIndex, int focalEnd, double scale) {
    TextStyle sized(TextStyle s) => scale == 1 ? s : s.copyWith(fontSize: (s.fontSize ?? 48) * scale);
    _prefix
      ..text = TextSpan(text: word.substring(0, focalIndex), style: sized(_base))
      ..textScaler = textScaler
      ..layout();
    _focal
      ..text = TextSpan(text: word.substring(focalIndex, focalEnd), style: sized(_focalStyle))
      ..textScaler = textScaler
      ..layout();
    _suffix
      ..text = TextSpan(text: word.substring(focalEnd), style: sized(_base))
      ..textScaler = textScaler
      ..layout();
  }

  void _paintGuides(Canvas canvas, Size size, double focalX) {
    final fontSize = textScaler.scale(style.text.fontSize ?? 48);
    final halfHeight = fontSize * 0.62;
    final centerY = size.height / 2;
    final paint = Paint()
      ..color = style.guideColor
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final lineInset = size.width * 0.12;
    final topY = centerY - halfHeight - _guideGap;
    final bottomY = centerY + halfHeight + _guideGap;

    canvas
      ..drawLine(Offset(lineInset, topY), Offset(size.width - lineInset, topY), paint..strokeWidth = 1)
      ..drawLine(Offset(lineInset, bottomY), Offset(size.width - lineInset, bottomY), paint)
      ..drawLine(Offset(focalX, topY), Offset(focalX, topY + _guideLength), paint..strokeWidth = 2)
      ..drawLine(Offset(focalX, bottomY), Offset(focalX, bottomY - _guideLength), paint);
  }

  @override
  bool shouldRepaint(RsvpWordPainter old) =>
      old.words != words || old.style != style || old.anchor != anchor || old.textScaler != textScaler;
}
