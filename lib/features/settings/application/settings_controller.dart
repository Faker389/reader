import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/providers.dart';
import '../../../domain/models/app_settings.dart';
import '../../../domain/models/reader_settings.dart';

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

final readerSettingsProvider =
    Provider<ReaderSettings>((ref) => ref.watch(settingsControllerProvider.select((s) => s.reader)));

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final settings = ref.watch(settingsRepositoryProvider).loadSettings();
    ref.read(analyticsProvider).setEnabled(settings.analyticsEnabled);
    return settings;
  }

  Future<void> update(AppSettings Function(AppSettings current) change) async {
    state = change(state);
    await ref.read(settingsRepositoryProvider).saveSettings(state);
  }

  Future<void> updateReader(ReaderSettings Function(ReaderSettings current) change) =>
      update((s) => s.copyWith(reader: change(s.reader)));

  Future<void> updateNotifications(NotificationPreferences Function(NotificationPreferences current) change) =>
      update((s) => s.copyWith(notifications: change(s.notifications)));

  Future<void> setAnalyticsEnabled(bool enabled) async {
    await update((s) => s.copyWith(analyticsEnabled: enabled));
    await ref.read(analyticsProvider).setEnabled(enabled);
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingController, OnboardingChoices>(OnboardingController.new);

class OnboardingController extends Notifier<OnboardingChoices> {
  @override
  OnboardingChoices build() => ref.watch(settingsRepositoryProvider).loadOnboarding();

  void setGoal(int minutes) => state = OnboardingChoices(
        completed: state.completed,
        goalMinutes: minutes,
        startingWpm: state.startingWpm,
      );

  void setStartingWpm(int wpm) => state = OnboardingChoices(
        completed: state.completed,
        goalMinutes: state.goalMinutes,
        startingWpm: wpm,
      );

  Future<void> complete() async {
    state = OnboardingChoices(completed: true, goalMinutes: state.goalMinutes, startingWpm: state.startingWpm);
    await ref.read(settingsRepositoryProvider).saveOnboarding(state);
    await ref
        .read(settingsControllerProvider.notifier)
        .updateReader((r) => r.copyWith(defaultWpm: state.startingWpm));
  }
}
