import 'dart:isolate';

import 'package:flutter/foundation.dart';

/// Runs [computation] off the UI isolate on devices that support isolates.
/// Browsers have a single isolate, so the work runs inline there.
Future<T> runOffload<T>(T Function() computation) {
  if (kIsWeb) return Future<T>.sync(computation);
  return Isolate.run(computation);
}
