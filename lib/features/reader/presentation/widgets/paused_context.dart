import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../theme/reader_theme.dart';
import '../../engine/rsvp_engine.dart';

/// While paused, shows the words around the current one so the reader can
/// regain context. Built only when paused, so it costs nothing while reading.
class PausedContext extends StatelessWidget {
  const PausedContext({required this.engine, required this.theme, super.key});

  final RsvpEngine engine;
  final ReaderTheme theme;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: engine.playing,
      builder: (context, playing, _) => AnimatedOpacity(
        opacity: playing ? 0 : 1,
        duration: MotionConstants.fast,
        child: playing
            ? const SizedBox.shrink()
            : ValueListenableBuilder<int>(
                valueListenable: engine.position,
                builder: (context, position, _) => _buildText(context, position),
              ),
      ),
    );
  }

  Widget _buildText(BuildContext context, int position) {
    final words = engine.content.words;
    const span = ReaderConstants.contextWordsWhenPaused;
    final start = (position - span).clamp(0, words.length);
    final end = (position + span + 1).clamp(0, words.length);
    final style = Theme.of(context).textTheme.bodyLarge!.copyWith(color: theme.chromeMuted, height: 1.6);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text.rich(
        TextSpan(children: [
          if (start > 0) const TextSpan(text: '… '),
          for (var i = start; i < end; i++)
            TextSpan(
              text: '${words[i]} ',
              style: i == position ? TextStyle(color: theme.word, fontWeight: FontWeight.w700) : null,
            ),
          if (end < words.length) const TextSpan(text: '…'),
        ]),
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}
