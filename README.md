# Fovea

A dedicated RSVP (rapid serial visual presentation) reading app for Flutter.
Words appear one at a time at a fixed focal point, so you can read without
moving your eyes, build speed gradually and keep a calm daily habit.

Open book → press start → words flow → build speed → track progress → build habit → finish books.

## Running it

```sh
flutter pub get
flutter run
```

With no Firebase project configured, the app runs in **device-only mode**:
accounts, books, sessions, statistics and achievements are stored locally
with Hive, and the UI tells the user their data stays on the device. This
lets you try the whole app before setting anything up.

Requirements: Flutter 3.29+ / Dart 3.7+. Android needs minSdk 23, NDK
27.0.12077973 and Kotlin 2.2.20, all already set in `android/`.

## Connecting Firebase

Search the repo for `TODO(firebase)` to find every place that needs attention.

1. Create a Firebase project and enable **Authentication** (Email/Password and
   Google), **Firestore**, **Storage**, **Crashlytics** and **Analytics**.
2. Run `flutterfire configure`. This replaces `lib/firebase_options.dart`
   and adds the platform config files. When the generated options are
   present, the app switches from device-only mode to Firebase automatically.
3. In `android/app/build.gradle.kts`, apply the `google-services` and
   Crashlytics Gradle plugins, as described in the TODO there.
4. Set up Google Sign-In:
   - Android: add your debug and release SHA-1 fingerprints to the Firebase
     Android app, then set the Web OAuth client ID in
     `lib/data/repositories/firebase_auth_repository.dart`.
   - iOS: add the reversed client ID URL scheme in `ios/Runner/Info.plist`.
5. Deploy the rules and the backend:

   ```sh
   firebase deploy --only firestore:rules,firestore:indexes,storage
   cd functions && npm install && npm run build && cd ..
   firebase deploy --only functions
   ```

   Set the region in `functions/src/index.ts` (currently `europe-west1`)
   to the one closest to your users.

You can also run everything locally with `firebase emulators:start`. The
emulator ports are configured in `firebase.json`.

## Security model

- All private data lives under `users/{uid}`. `firestore.rules` restricts
  every document under that path to its owner.
- Clients may only write whitelisted fields. Book documents hold metadata
  only, never book text. Imported book content stays in the app's private
  storage on the device and is never uploaded.
- Reading sessions are create-only and validated: durations, word counts and
  WPM are bounds-checked, and implausible reading rates are rejected.
- **Statistics, streaks and achievements are computed on the server.** The
  `onSessionCreated` Cloud Function processes each session exactly once
  (using idempotency markers in `processedSessions`), updates the
  aggregates and awards achievements. Clients can read these documents but
  never write them.
- `storage.rules` only allows a user to upload their own avatar
  (JPEG or PNG, under 5 MB).
- Deleting an account removes the user's Firestore data, Storage files and
  local data. The `onUserDeleted` function cleans up anything left behind.
- User-facing errors go through `AppFailure`, so raw Firebase or Dart
  exceptions are never shown.

## Project layout

```
lib/
  core/        constants, errors, formatting, sanitising, shared providers
  domain/      models and pure reading logic (tokenizer, focal point, WPM scale, timing)
  data/        repositories, local (Hive) and remote (Firestore) sources, importers, samples
  services/    analytics, crash reporting, haptics, notifications, session recording
  features/    onboarding, auth, home, library, import, reader (incl. the RSVP
               engine), statistics, achievements, profile, settings
  routing/     GoRouter configuration and redirects
  theme/       app and reader themes, typography
  widgets/     shared UI components
functions/     Cloud Functions (TypeScript): session processing, achievements, cleanup
test/          RSVP engine timing tests and reading-domain tests
tool/          sample-book preparation script
```

The RSVP engine (`lib/features/reader/engine/`) schedules each word against absolute
deadlines instead of chaining timers, so the timing doesn't drift over long
sessions. The base duration is `60000 / WPM` ms per word, with configurable
extra pauses for punctuation, long words, numbers, paragraphs and chapters.
The clock and timer are injectable, and `test/rsvp_engine_test.dart` checks
the timing exactly.

## Sample books

The five bundled books (`assets/books/`) are public-domain texts from
[Project Gutenberg](https://www.gutenberg.org/): *Alice's Adventures in
Wonderland*, *The Great Gatsby*, *Pride and Prejudice*, *Meditations*
(George Long translation) and *The Adventures of Sherlock Holmes*.
`tool/prepare_samples.dart` strips the Gutenberg headers, licence text and
tables of contents from the raw downloads in `tool/raw/`. *The Great Gatsby*
is public domain in the US since 2021; check the status in other
jurisdictions before distributing the app there. Never bundle copyrighted
books.

## Before release

Search for `TODO(release)`:

- Choose your own application ID (`android/app/build.gradle.kts`) and bundle ID.
- Bundle the font files locally (`lib/theme/app_typography.dart`).
- Have the Terms and Privacy Policy reviewed
  (`lib/features/profile/presentation/info_screen.dart`).

## Tests

```sh
flutter analyze
flutter test
```

## Troubleshooting

- **"Could not close incremental caches" on Windows.** This happens when the
  project and the pub cache are on different drives. Incremental Kotlin
  compilation is disabled in `android/gradle.properties` to avoid it.
- **Plugin build errors mentioning `compilerOptions` or Kotlin metadata.**
  Keep the Kotlin version in `android/settings.gradle.kts` at 2.2.20 or newer.
