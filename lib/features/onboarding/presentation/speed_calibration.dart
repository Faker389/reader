import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/reading/wpm_scale.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/buttons.dart';
import 'rsvp_demo.dart';

/// Plays a short passage that gets faster until the reader says it is too fast.
/// The pace just before that becomes their starting speed.
class SpeedCalibration extends StatefulWidget {
  const SpeedCalibration({required this.active, required this.onPace, super.key});

  final bool active;
  final ValueChanged<int> onPace;

  @override
  State<SpeedCalibration> createState() => _SpeedCalibrationState();
}

class _SpeedCalibrationState extends State<SpeedCalibration> {
  static const _passage =
      'The morning was quiet and the page was waiting. You do not need to chase the words. '
      'Let them arrive in one place and follow the meaning. If the pace feels rushed, that is useful. '
      'Comfortable reading is the point, and speed can grow from there. A clear sentence is worth '
      'more than a blur of pages. Stay with the thought until it settles, then let the next one come.';

  static const _ladder = [150, 180, 220, 250, 300, 360, 420, 500];

  int _step = 0;
  bool _chosen = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.active) _arm();
  }

  @override
  void didUpdateWidget(SpeedCalibration old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active && !_chosen) _arm();
    if (!widget.active) _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted || _chosen || _step >= _ladder.length - 1) return;
      setState(() => _step++);
    });
  }

  void _keep() => _choose(_ladder[_step]);

  void _tooFast() => _choose(_step == 0 ? _ladder.first : _ladder[_step - 1]);

  void _choose(int wpm) {
    _timer?.cancel();
    setState(() => _chosen = true);
    widget.onPace(WpmScale.snap(wpm));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final wpm = _ladder[_step];
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Find your speed.', style: context.text.displaySmall),
              const SizedBox(height: 10),
              Text(
                'This passage gets faster on its own. Stop it when reading stops feeling easy. '
                'You can skip this and keep the speed you already picked.',
                style: context.text.bodyLarge?.copyWith(color: c.muted),
              ),
              const SizedBox(height: 28),
              Center(
                child: RsvpDemo(text: _passage, wpm: wpm, fontSize: 36, playing: widget.active && !_chosen),
              ),
              const SizedBox(height: 8),
              Center(child: Text('$wpm WPM', style: context.text.titleMedium)),
              const SizedBox(height: 20),
              if (_chosen)
                Text('Saved. You can change it any time while reading.', style: context.text.bodyMedium)
              else ...[
                PrimaryButton(label: 'This pace is right', onPressed: widget.active ? _keep : null),
                const SizedBox(height: 10),
                SecondaryButton(label: 'Too fast', onPressed: widget.active ? _tooFast : null),
              ],
            ],
          ),
        ),
      );
    });
  }
}
