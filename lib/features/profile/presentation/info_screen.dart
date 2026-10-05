import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_colors.dart';

/// Static help and legal pages.
///
/// TODO(release): Have the Terms and Privacy Policy reviewed by counsel and
/// host canonical versions on the web (app stores require a public URL).
class InfoScreen extends StatelessWidget {
  const InfoScreen({required this.page, super.key});

  final InfoPage page;

  @override
  Widget build(BuildContext context) {
    final (title, sections) = switch (page) {
      InfoPage.help => ('Help', _help),
      InfoPage.terms => ('Terms of Use', _terms),
      InfoPage.privacyPolicy => ('Privacy Policy', _privacy),
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              for (final (heading, body) in sections) ...[
                const SizedBox(height: 20),
                Text(heading, style: context.text.titleMedium),
                const SizedBox(height: 8),
                Text(body, style: context.text.bodyLarge?.copyWith(color: context.colors.muted)),
              ],
              const SizedBox(height: 32),
              Text('Questions? ${AppInfo.supportEmail}', style: context.text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

const _help = [
  (
    'How RSVP reading works',
    'Rapid Serial Visual Presentation shows one word at a time in a fixed spot. Your eyes '
        'stay still, so the time normally spent moving between words goes into reading. The '
        'highlighted letter marks the point your eye recognises a word fastest.',
  ),
  (
    'Controls',
    'Tap the screen to show or hide controls. Swipe left or right to jump 10 words. Swipe up '
        'or down to change speed. Long-press to pause. Tap the WPM value for precise speeds and presets.',
  ),
  (
    'Choosing a speed',
    'Comfort and comprehension matter more than raw speed. Start where reading feels easy, then '
        'raise the speed in small steps over several sessions. Slowing down for dense material is normal.',
  ),
  (
    'Natural rhythm',
    'With natural rhythm on, Fovea pauses briefly at commas, sentence ends and paragraph breaks, '
        'and gives long words a little more time. You can tune or disable each pause in Reader settings.',
  ),
  (
    'Importing books',
    'Import EPUB, TXT or CSV files from the Library. DRM-protected ebooks cannot be opened. '
        'Imported text stays on your device; only reading progress and statistics sync to your account.',
  ),
  (
    'Streaks and goals',
    'A streak counts consecutive days on which you reach your daily goal. Missing a day simply '
        'starts a new streak — there are no penalties.',
  ),
];

const _terms = [
  (
    'Using Fovea',
    'Fovea is a reading tool for personal use. You are responsible for the content you import and '
        'must have the right to read it. Do not use Fovea to distribute copyrighted material.',
  ),
  (
    'Your content',
    'Books you import remain yours. They are stored privately on your device and are never '
        'published or shared by Fovea.',
  ),
  (
    'Sample books',
    'Bundled sample books are public-domain texts sourced from Project Gutenberg, with the '
        'Gutenberg licence headers removed as permitted for public-domain works.',
  ),
  (
    'Accounts',
    'Keep your sign-in details secure. You can delete your account at any time from '
        'Profile → Account, which permanently removes your data.',
  ),
  (
    'No warranty',
    'Fovea is provided as is. Reading speeds vary by person and material; Fovea does not '
        'promise any particular speed or comprehension outcome.',
  ),
];

const _privacy = [
  (
    'What we store',
    'Your name, email, reading goal, preferred speed, reading sessions (duration, words, speed), '
        'book progress and achievements. This powers your statistics and lets progress follow you '
        'between devices.',
  ),
  (
    'What we never upload',
    'The text of books you import. Book files stay on your device. Only titles, authors and '
        'progress are synced so your library looks the same everywhere.',
  ),
  (
    'Analytics',
    'If enabled, Fovea records anonymous product events (for example, "session completed") '
        'without book titles or personal details. You can turn analytics off in Profile → Privacy.',
  ),
  (
    'Crash reports',
    'Crash reports help us fix problems. They include technical details and an anonymous user '
        'identifier, never book content.',
  ),
  (
    'Deleting your data',
    'Deleting your account removes your profile, sessions, achievements, statistics and library '
        'metadata from our servers and erases local data on this device.',
  ),
];
