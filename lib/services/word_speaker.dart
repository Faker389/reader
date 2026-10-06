import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Speaks the words currently on screen, then stops as soon as they change.
class WordSpeaker {
  WordSpeaker({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  int _token = 0;
  double? _pluginRate;
  bool _prepared = false;

  /// [relativeRate] is 1 at an ordinary speaking pace.
  Future<void> speak(String phrase, {required double relativeRate}) async {
    final token = ++_token;
    final text = phrase.trim();
    if (text.isEmpty) return;
    try {
      await _prepare();
      if (token != _token) return;
      await _tts.stop();
      if (token != _token) return;
      final rate = _pluginRateFor(relativeRate);
      if (_pluginRate != rate) {
        _pluginRate = rate;
        await _tts.setSpeechRate(rate);
        if (token != _token) return;
      }
      await _tts.speak(text);
    } on Object {
      // Voice is optional. A missing speech engine stays silent.
    }
  }

  Future<void> stop() async {
    _token++;
    try {
      await _tts.stop();
    } on Object {
      // Already silent.
    }
  }

  Future<void> _prepare() async {
    if (_prepared) return;
    _prepared = true;
    await _tts.awaitSpeakCompletion(false);
  }

  /// flutter_tts treats 0.5 as a normal pace on phones, and 1.0 on the web.
  static double _pluginRateFor(double relative) {
    final paced = relative.clamp(0.75, 1.65);
    if (kIsWeb) return paced;
    return (0.5 * paced).clamp(0.35, 0.9);
  }
}
