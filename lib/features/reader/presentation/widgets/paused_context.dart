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
    final content = engine.content;
    if (content.isEmpty) return const SizedBox.shrink();
    final start = content.sentenceStart(position);
    final end = content.sentenceEnd(position);
    final style = Theme.of(context).textTheme.bodyLarge!.copyWith(color: theme.chromeMuted, height: 1.55);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Text.rich(
        TextSpan(children: [
          for (var i = start; i < end; i++)
            TextSpan(
              text: i == end - 1 ? content.words[i] : '${content.words[i]} ',
              style: i == position ? TextStyle(color: theme.word, fontWeight: FontWeight.w700) : null,
            ),
        ]),
        textAlign: TextAlign.center,
        maxLines: 6,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}
