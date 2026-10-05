import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'core/providers.dart';

Future<void> main() async {
  final environment = await bootstrap();
  runApp(
    ProviderScope(
      // Failures are surfaced to the UI as friendly states; automatic retries
      // would only hide them.
      retry: (retryCount, error) => null,
      overrides: [appEnvironmentProvider.overrideWithValue(environment)],
      child: const FoveaApp(),
    ),
  );
}
