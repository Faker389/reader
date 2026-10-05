import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Product analytics event names. Parameters are deliberately coarse and never
/// include book titles, text, names or emails.
abstract final class AnalyticsEvents {
  static const String onboardingCompleted = 'onboarding_completed';
  static const String bookImported = 'book_imported';
  static const String bookStarted = 'book_started';
  static const String readingSessionStarted = 'reading_session_started';
  static const String readingSessionCompleted = 'reading_session_completed';
  static const String wpmChanged = 'wpm_changed';
  static const String bookCompleted = 'book_completed';
  static const String achievementUnlocked = 'achievement_unlocked';
}

abstract interface class AnalyticsService {
  Future<void> log(String event, [Map<String, Object> parameters = const {}]);
  Future<void> setEnabled(bool enabled);
}

class DebugAnalyticsService implements AnalyticsService {
  DebugAnalyticsService();

  bool _enabled = true;

  @override
  Future<void> log(String event, [Map<String, Object> parameters = const {}]) async {
    if (_enabled && kDebugMode) debugPrint('[analytics] $event $parameters');
  }

  @override
  Future<void> setEnabled(bool enabled) async => _enabled = enabled;
}

class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService([FirebaseAnalytics? analytics])
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;
  bool _enabled = true;

  @override
  Future<void> log(String event, [Map<String, Object> parameters = const {}]) async {
    if (!_enabled) return;
    try {
      await _analytics.logEvent(name: event, parameters: parameters);
    } on Object catch (e) {
      debugPrint('Analytics failed: $e');
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    await _analytics.setAnalyticsCollectionEnabled(enabled);
  }
}
