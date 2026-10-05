import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../core/utils/json.dart';
import 'firestore_paths.dart';
import 'remote_data_source.dart';

class FirestoreRemoteDataSource implements RemoteDataSource {
  FirestoreRemoteDataSource({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  static const int _deleteBatchSize = 400;

  @override
  bool get isAvailable => true;

  @override
  Future<JsonMap?> fetchProfile(String uid) async {
    final snapshot = await _db.doc(FirestorePaths.user(uid)).get();
    return snapshot.data();
  }

  @override
  Future<void> upsertProfile(String uid, JsonMap editableFields) => _db
      .doc(FirestorePaths.user(uid))
      .set({...editableFields, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

  @override
  Future<List<JsonMap>> fetchBooks(String uid) async {
    final query = await _db.collection(FirestorePaths.userBooks(uid)).get();
    return [for (final doc in query.docs) doc.data()];
  }

  @override
  Future<void> upsertBook(String uid, JsonMap metadata) => _db
      .collection(FirestorePaths.userBooks(uid))
      .doc(metadata['id'] as String)
      .set(metadata, SetOptions(merge: true));

  @override
  Future<void> deleteBook(String uid, String bookId) =>
      _db.collection(FirestorePaths.userBooks(uid)).doc(bookId).delete();

  @override
  Future<List<JsonMap>> fetchSessions(String uid) async {
    final query = await _db.collection(FirestorePaths.userSessions(uid)).orderBy('startTime').get();
    return [for (final doc in query.docs) doc.data()];
  }

  @override
  Future<void> addSession(String uid, JsonMap session) => _db
      .collection(FirestorePaths.userSessions(uid))
      .doc(session['sessionId'] as String)
      .set(session);

  @override
  Future<List<JsonMap>> fetchAchievements(String uid) async {
    final query = await _db.collection(FirestorePaths.userAchievements(uid)).get();
    return [
      for (final doc in query.docs) {...doc.data(), 'id': doc.id, 'verified': true},
    ];
  }

  @override
  Future<String> uploadAvatar(String uid, Uint8List bytes, String contentType) async {
    final ref = _storage.ref(FirestorePaths.avatar(uid));
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  @override
  Future<void> deleteAllUserData(String uid) async {
    for (final collection in [
      FirestorePaths.userBooks(uid),
      FirestorePaths.userSessions(uid),
      FirestorePaths.userAchievements(uid),
      FirestorePaths.userStatistics(uid),
    ]) {
      await _deleteCollection(collection);
    }
    await _db.doc(FirestorePaths.user(uid)).delete();
    try {
      await _storage.ref(FirestorePaths.avatar(uid)).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }

  Future<void> _deleteCollection(String path) async {
    while (true) {
      final page = await _db.collection(path).limit(_deleteBatchSize).get();
      if (page.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in page.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
