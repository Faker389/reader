import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'data/providers.dart';
import 'domain/models/app_settings.dart';
import 'features/settings/application/settings_controller.dart';
import 'features/statistics/application/stats_providers.dart';
import 'routing/app_router.dart';
import 'services/reminder_scheduler.dart';
import 'theme/app_theme.dart';

class FoveaApp extends ConsumerStatefulWidget {
  const FoveaApp({super.key});

  @override
  ConsumerState<FoveaApp> createState() => _FoveaAppState();
}

class _FoveaAppState extends ConsumerState<FoveaApp> with WidgetsBindingObserver {
  static const double _largeTextFactor = 1.18;
  static const double _maxTextScale = 2.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    ref.read(dayKeyProvider.notifier).refresh();
    if (ref.read(currentUidProvider) == null) return;
    unawaited(ref.read(syncServiceProvider).synchronize());
    unawaited(ref.read(reminderSchedulerProvider).reschedule());
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light(highContrast: settings.highContrast),
      darkTheme: AppTheme.dark(highContrast: settings.highContrast),
      themeMode: switch (settings.theme) {
        AppThemePreference.dark => ThemeMode.dark,
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.system => ThemeMode.system,
      },
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final scaler = settings.largeText
            ? TextScaler.linear(media.textScaler.scale(1) * _largeTextFactor)
            : media.textScaler;
        return MediaQuery(
          data: media.copyWith(
            disableAnimations: media.disableAnimations || settings.reduceMotion,
            textScaler: scaler.clamp(maxScaleFactor: _maxTextScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
