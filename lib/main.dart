import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'core/providers.dart';

Future<void> main() async {
  try {
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
  } catch (error, stack) {
    debugPrint('Startup failed: $error\n$stack');
    WidgetsFlutterBinding.ensureInitialized();
    runApp(const _StartupFailedApp());
  }
}

class _StartupFailedApp extends StatelessWidget {
  const _StartupFailedApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              "Fovea couldn't start. Please close the tab and try again.",
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
