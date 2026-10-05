/// Route locations in one place so navigation calls never use raw strings.
abstract final class Routes {
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String signIn = '/auth/sign-in';
  static const String signUp = '/auth/sign-up';
  static const String forgotPassword = '/auth/forgot-password';

  static const String home = '/home';
  static const String library = '/library';
  static const String statistics = '/stats';
  static const String achievements = '/achievements';
  static const String profile = '/profile';

  static const String import = '/import';
  static const String sessionSummary = '/session-summary';

  static const String readerSettings = '/settings/reader';
  static const String appearanceSettings = '/settings/appearance';
  static const String notificationSettings = '/settings/notifications';
  static const String accountSettings = '/settings/account';
  static const String privacy = '/settings/privacy';

  static String book(String id) => '/book/$id';
  static String reader(String id, {int? start}) => start == null ? '/reader/$id' : '/reader/$id?start=$start';
  static String info(InfoPage page) => '/info/${page.name}';
}

enum InfoPage { terms, help, privacyPolicy }
