/// Relative paths inside a user's private storage. The same keys are used
/// on disk and in the browser store.
abstract final class FileLocations {
  static String contentPath(String bookId) => 'books/$bookId.json';

  static String coverPath(String bookId, String extension) =>
      'covers/$bookId-${DateTime.now().millisecondsSinceEpoch}.$extension';

  static const String avatarPath = 'avatar';
}
