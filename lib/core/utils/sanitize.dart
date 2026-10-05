/// Input sanitisation for user-entered and imported text.
abstract final class Sanitize {
  static final RegExp _control = RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]');
  static final RegExp _spaces = RegExp(r'\s+');

  /// Single-line field such as a title or author name.
  static String line(String input, {required int maxLength}) {
    final cleaned = input.replaceAll(_control, '').replaceAll(_spaces, ' ').trim();
    return cleaned.length <= maxLength ? cleaned : cleaned.substring(0, maxLength).trim();
  }

  /// Body text: removes control characters and normalises whitespace.
  static String text(String input) =>
      input.replaceAll(_control, '').replaceAll(_spaces, ' ').trim();

  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static bool isEmail(String input) => _email.hasMatch(input.trim());

  static String? validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email';
    if (!isEmail(v)) return "That email doesn't look right";
    return null;
  }

  static String? validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Enter a password';
    if (v.length < 8) return 'Use at least 8 characters';
    return null;
  }

  static String? validateName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Tell us what to call you';
    if (v.length > 60) return 'Keep it under 60 characters';
    return null;
  }
}
