import 'dart:typed_data';

import '../../core/utils/json.dart';

/// Abstraction over the cloud backend so repositories never talk to Firebase
/// directly and the app runs fully offline when Firebase isn't configured.
abstract interface class RemoteDataSource {
  bool get isAvailable;

  Future<JsonMap?> fetchProfile(String uid);
  Future<void> upsertProfile(String uid, JsonMap editableFields);

  Future<List<JsonMap>> fetchBooks(String uid);
  Future<void> upsertBook(String uid, JsonMap metadata);
  Future<void> deleteBook(String uid, String bookId);

  Future<List<JsonMap>> fetchSessions(String uid);
  Future<void> addSession(String uid, JsonMap session);

  Future<List<JsonMap>> fetchAchievements(String uid);

  /// Uploads a private avatar and returns its download URL.
  Future<String> uploadAvatar(String uid, Uint8List bytes, String contentType);

  Future<void> deleteAllUserData(String uid);
}

class NoopRemoteDataSource implements RemoteDataSource {
  const NoopRemoteDataSource();

  @override
  bool get isAvailable => false;

  @override
  Future<JsonMap?> fetchProfile(String uid) async => null;

  @override
  Future<void> upsertProfile(String uid, JsonMap editableFields) async {}

  @override
  Future<List<JsonMap>> fetchBooks(String uid) async => const [];

  @override
  Future<void> upsertBook(String uid, JsonMap metadata) async {}

  @override
  Future<void> deleteBook(String uid, String bookId) async {}

  @override
  Future<List<JsonMap>> fetchSessions(String uid) async => const [];

  @override
  Future<void> addSession(String uid, JsonMap session) async {}

  @override
  Future<List<JsonMap>> fetchAchievements(String uid) async => const [];

  @override
  Future<String> uploadAvatar(String uid, Uint8List bytes, String contentType) =>
      throw UnsupportedError('Cloud storage is not configured');

  @override
  Future<void> deleteAllUserData(String uid) async {}
}
