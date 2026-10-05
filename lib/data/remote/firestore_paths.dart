/// Firestore layout. Must match `firestore.rules` and the Cloud Functions.
///
///   users/{uid}
///   users/{uid}/books/{bookId}            book metadata + progress (no text)
///   users/{uid}/sessions/{sessionId}      immutable session logs
///   users/{uid}/achievements/{id}         written only by Cloud Functions
///   users/{uid}/statistics/{yyyy-MM-dd}   written only by Cloud Functions
///   global/catalog/books/{bookId}         public-domain catalogue, read-only
abstract final class FirestorePaths {
  static const String users = 'users';
  static const String books = 'books';
  static const String sessions = 'sessions';
  static const String achievements = 'achievements';
  static const String statistics = 'statistics';

  static String user(String uid) => '$users/$uid';
  static String userBooks(String uid) => '${user(uid)}/$books';
  static String userSessions(String uid) => '${user(uid)}/$sessions';
  static String userAchievements(String uid) => '${user(uid)}/$achievements';
  static String userStatistics(String uid) => '${user(uid)}/$statistics';

  static const String globalCatalog = 'global/catalog/books';

  static String avatar(String uid) => 'users/$uid/avatar.jpg';
}
