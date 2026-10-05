import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../domain/reading/wpm_scale.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/buttons.dart';

/// Full WPM control: large readout, stepped slider, ± buttons, presets and
/// direct numeric entry.
class WpmPicker extends StatefulWidget {
  const WpmPicker({required this.value, required this.onChanged, super.key});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<WpmPicker> createState() => _WpmPickerState();
}

class _WpmPickerState extends State<WpmPicker> {
  static const List<int> _presets = [WpmPreset.slow, WpmPreset.comfortable, WpmPreset.fast, WpmPreset.veryFast];

  late int _value = widget.value;
  bool _editing = false;
  late final TextEditingController _input = TextEditingController(text: '${widget.value}');

  @override
  void didUpdateWidget(WpmPicker old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && widget.value != _value) _value = widget.value;
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _set(int value) {
    final clamped = WpmScale.clamp(value);
    if (clamped == _value) return;
    HapticFeedback.selectionClick();
    setState(() => _value = clamped);
    widget.onChanged(clamped);
  }

  void _submitCustom() {
    final parsed = int.tryParse(_input.text.trim());
    setState(() => _editing = false);
    if (parsed != null) _set(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final index = WpmScale.indexOf(_value);
    final isPreset = _presets.contains(_value);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleIconButton(
              icon: Icons.remove_rounded,
              tooltip: 'Slower',
              onPressed: _value <= ReaderConstants.minWpm ? null : () => _set(WpmScale.step(_value, -1)),
            ),
            Expanded(
              child: _editing
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: TextField(
                        controller: _input,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                        style: AppTypography.numeric(context.text.displaySmall!),
                        decoration: InputDecoration(
                          helperText: '${ReaderConstants.minWpm}–${ReaderConstants.maxWpm} WPM',
                          helperStyle: context.text.bodySmall,
                        ),
                        onSubmitted: (_) => _submitCustom(),
                        onTapOutside: (_) => _submitCustom(),
                      ),
                    )
                  : Semantics(
                      button: true,
                      label: '$_value words per minute. Tap to type a value.',
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _input.text = '$_value';
                          _editing = true;
                        }),
                        child: Column(
                          children: [
                            Text('$_value', style: AppTypography.numeric(context.text.displayMedium!)),
                            Text('WORDS PER MINUTE', style: context.text.labelSmall),
                          ],
                        ),
                      ),
                    ),
            ),
            CircleIconButton(
              icon: Icons.add_rounded,
              tooltip: 'Faster',
              onPressed: _value >= ReaderConstants.maxWpm ? null : () => _set(WpmScale.step(_value, 1)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Slider(
          value: index.toDouble(),
          max: (WpmScale.values.length - 1).toDouble(),
          divisions: WpmScale.values.length - 1,
          semanticFormatterCallback: (v) => '${WpmScale.values[v.round()]} words per minute',
          onChanged: (v) => _set(WpmScale.values[v.round()]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${ReaderConstants.minWpm}', style: context.text.bodySmall),
              Text('${ReaderConstants.maxWpm}', style: context.text.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final preset in _presets)
              ChoiceChip(
                label: Text('${WpmScale.presetLabel(preset)} · $preset'),
                selected: _value == preset,
                showCheckmark: false,
                onSelected: (_) => _set(preset),
              ),
            ChoiceChip(
              label: const Text('Custom'),
              selected: !isPreset,
              showCheckmark: false,
              onSelected: (_) => setState(() {
                _input.text = '$_value';
                _editing = true;
              }),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Find the pace where you still follow comfortably. Everyone\'s is different, and it changes with the text.',
          textAlign: TextAlign.center,
          style: context.text.bodySmall?.copyWith(color: c.subtle),
        ),
      ],
    );
  }
}

Future<void> showWpmSheet(BuildContext context, {required int initial, required ValueChanged<int> onChanged}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(child: WpmPicker(value: initial, onChanged: onChanged)),
      ),
    ),
  );
}
