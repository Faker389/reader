import '../../domain/models/app_settings.dart';
import '../local/json_store.dart';

/// Device-wide preferences stored in the app box.
class SettingsRepository {
  SettingsRepository(this._store);

  final KeyValueStore _store;

  static const String _settingsKey = 'settings';
  static const String _onboardingKey = 'onboarding';

  AppSettings loadSettings() {
    final json = _store.getJson(_settingsKey);
    return json == null ? const AppSettings() : AppSettings.fromJson(json);
  }

  Future<void> saveSettings(AppSettings settings) => _store.putJson(_settingsKey, settings.toJson());

  OnboardingChoices loadOnboarding() {
    final json = _store.getJson(_onboardingKey);
    return json == null ? const OnboardingChoices() : OnboardingChoices.fromJson(json);
  }

  Future<void> saveOnboarding(OnboardingChoices choices) => _store.putJson(_onboardingKey, choices.toJson());
}
