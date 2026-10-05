import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/models/reader_settings.dart';
import '../../../domain/reading/word_timing.dart';
import '../../../domain/reading/tokenizer.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../reader/presentation/widgets/rsvp_word_view.dart';

/// A looping, self-contained RSVP preview used in onboarding.
class RsvpDemo extends StatefulWidget {
  const RsvpDemo({
    required this.text,
    this.wpm = 250,
    this.fontSize = 44,
    this.playing = true,
    super.key,
  });

  final String text;
  final int wpm;
  final double fontSize;
  final bool playing;

  @override
  State<RsvpDemo> createState() => _RsvpDemoState();
}

class _RsvpDemoState extends State<RsvpDemo> {
  late List<String> _words = _split(widget.text);
  final ValueNotifier<int> _position = ValueNotifier(0);
  Timer? _timer;

  static List<String> _split(String text) => text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  @override
  void initState() {
    super.initState();
    if (widget.playing) _scheduleNext();
  }

  @override
  void didUpdateWidget(RsvpDemo old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _words = _split(widget.text);
      _position.value = 0;
    }
    if (old.playing != widget.playing || old.wpm != widget.wpm || old.text != widget.text) {
      _timer?.cancel();
      if (widget.playing) _scheduleNext();
    }
  }

  void _scheduleNext() {
    final word = _words[_position.value];
    final micros =
        WordTiming.durationMicros(word, Tokenizer.flagsFor(word), widget.wpm.toDouble(), const WordTimingConfig());
    final atEnd = _position.value == _words.length - 1;
    _timer = Timer(Duration(microseconds: atEnd ? micros * 4 : micros), () {
      if (!mounted) return;
      _position.value = atEnd ? 0 : _position.value + 1;
      _scheduleNext();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return RsvpWordView(
      words: _words,
      position: _position,
      height: widget.fontSize * 2.6,
      style: RsvpWordStyle(
        text: AppTypography.readerStyle(ReaderFont.sans, size: widget.fontSize, weight: FontWeight.w500),
        wordColor: c.text,
        focalColor: c.accent,
        guideColor: c.border,
        focalMode: FocalMode.accent,
        showGuides: true,
      ),
    );
  }
}
