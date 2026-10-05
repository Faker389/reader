import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';
import '../features/achievements/presentation/achievements_screen.dart';
import '../features/auth/application/user_session.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/home/presentation/main_shell.dart';
import '../features/import/presentation/import_screen.dart';
import '../features/library/presentation/book_details_screen.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/onboarding/presentation/splash_screen.dart';
import '../features/profile/presentation/account_screen.dart';
import '../features/profile/presentation/info_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/reader/presentation/reader_screen.dart';
import '../features/reader/presentation/session_summary_screen.dart';
import '../features/settings/application/settings_controller.dart';
import '../features/settings/presentation/appearance_settings_screen.dart';
import '../features/settings/presentation/notification_settings_screen.dart';
import '../features/settings/presentation/privacy_screen.dart';
import '../features/settings/presentation/reader_settings_screen.dart';
import '../features/statistics/presentation/statistics_screen.dart';
import '../services/session_recorder.dart';
import 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Re-evaluates redirects whenever auth, onboarding or session readiness
/// changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(onboardingProvider.select((o) => o.completed), (_, __) => notifyListeners());
    ref.listen(userSessionReadyProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref, state.matchedLocation),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.onboarding, builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: Routes.signIn, builder: (_, __) => const SignInScreen()),
      GoRoute(path: Routes.signUp, builder: (_, __) => const SignUpScreen()),
      GoRoute(path: Routes.forgotPassword, builder: (_, __) => const ForgotPasswordScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.library, builder: (_, __) => const LibraryScreen())]),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.statistics, builder: (_, __) => const StatisticsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.achievements, builder: (_, __) => const AchievementsScreen())],
          ),
          StatefulShellBranch(routes: [GoRoute(path: Routes.profile, builder: (_, __) => const ProfileScreen())]),
        ],
      ),
      GoRoute(
        path: '/book/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) => BookDetailsScreen(bookId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/reader/:id',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: const Duration(milliseconds: 350),
          child: ReaderScreen(
            bookId: state.pathParameters['id']!,
            startIndex: int.tryParse(state.uri.queryParameters['start'] ?? ''),
          ),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child),
        ),
      ),
      GoRoute(
        path: Routes.sessionSummary,
        parentNavigatorKey: _rootKey,
        redirect: (_, state) => state.extra is SessionSummary ? null : Routes.home,
        builder: (_, state) => SessionSummaryScreen(summary: state.extra! as SessionSummary),
      ),
      GoRoute(path: Routes.import, parentNavigatorKey: _rootKey, builder: (_, __) => const ImportScreen()),
      GoRoute(path: Routes.readerSettings, builder: (_, __) => const ReaderSettingsScreen()),
      GoRoute(path: Routes.appearanceSettings, builder: (_, __) => const AppearanceSettingsScreen()),
      GoRoute(path: Routes.notificationSettings, builder: (_, __) => const NotificationSettingsScreen()),
      GoRoute(path: Routes.accountSettings, builder: (_, __) => const AccountScreen()),
      GoRoute(path: Routes.privacy, builder: (_, __) => const PrivacyScreen()),
      GoRoute(
        path: '/info/:page',
        builder: (_, state) => InfoScreen(
          page: InfoPage.values.firstWhere(
            (p) => p.name == state.pathParameters['page'],
            orElse: () => InfoPage.help,
          ),
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

String? _redirect(Ref ref, String location) {
  final auth = ref.read(authStateProvider);
  final onboarded = ref.read(onboardingProvider).completed;
  final atSplash = location == Routes.splash;
  final inOnboarding = location.startsWith(Routes.onboarding);
  final inAuth = location.startsWith('/auth');
  final inInfo = location.startsWith('/info');

  if (!auth.hasValue && !auth.hasError) return atSplash ? null : Routes.splash;

  final user = auth.value;
  if (user == null) {
    if (inInfo) return null;
    if (!onboarded) return inOnboarding ? null : Routes.onboarding;
    return inAuth ? null : Routes.signIn;
  }

  final ready = ref.read(userSessionReadyProvider);
  if (!ready.hasValue && !ready.hasError) return atSplash ? null : Routes.splash;

  if (atSplash || inAuth || inOnboarding) return Routes.home;
  return null;
}
