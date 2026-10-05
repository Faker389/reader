import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/providers.dart';
import '../../../services/reminder_scheduler.dart';
import '../../../services/session_recorder.dart';
import '../../settings/application/settings_controller.dart';

/// Name typed during sign-up, applied once the new user's profile exists.
final pendingSignUpNameProvider = NotifierProvider<PendingNameController, String?>(PendingNameController.new);

class PendingNameController extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? name) => state = name;
}

/// Prepares a signed-in user's local world: profile, sample books, recovery
/// of an interrupted session, then background sync. The router holds the
/// splash screen until this completes.
final userSessionReadyProvider = FutureProvider<void>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return;
  final user = ref.read(currentUserProvider)!;
  final scope = ref.watch(userScopeProvider);
  final crash = ref.read(crashReporterProvider);

  final profile = await scope.profile.ensure(user, ref.read(onboardingProvider));
  final pendingName = ref.read(pendingSignUpNameProvider);
  if (pendingName != null) {
    if (pendingName.isNotEmpty && pendingName != profile.name) await scope.profile.setName(pendingName);
    ref.read(pendingSignUpNameProvider.notifier).set(null);
  }
  try {
    await scope.books.seedSamples();
  } on Object catch (e, s) {
    crash.recordNonFatal(e, s, reason: 'seed samples');
  }
  try {
    await ref.read(sessionRecorderProvider).recoverDraft();
  } on Object catch (e, s) {
    crash.recordNonFatal(e, s, reason: 'recover draft');
  }
  unawaited(scope.sync.synchronize());
  unawaited(ref.read(reminderSchedulerProvider).reschedule());
});
