import 'dart:convert';
import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';

import 'file_locations.dart';
import 'local_database.dart';

/// Browser storage for book text and images. `path_provider` has no web
/// implementation, so files live in IndexedDB beside the Hive database
/// instead of a documents directory.
class FileStore {
  FileStore._(this._box);

  static const String _boxName = 'fovea_files';

  static Future<FileStore> open() async {
    final box = await Hive.openBox<String>(_boxName);
    return FileStore._(box);
  }

  final Box<String> _box;

  UserFiles forUser(String uid) => UserFiles._(_box, LocalDatabase.scopeKey(uid));
}

class UserFiles {
  UserFiles._(this._box, this._prefix);

  static String contentPath(String bookId) => FileLocations.contentPath(bookId);
  static String coverPath(String bookId, String extension) => FileLocations.coverPath(bookId, extension);
  static const String avatarPath = FileLocations.avatarPath;

  final Box<String> _box;
  final String _prefix;

  String _key(String relative) => '$_prefix/$relative';

  /// Browsers have no filesystem path for these files.
  String? filesystemPath(String relative) => null;

  Future<void> writeString(String relative, String contents) => _box.put(_key(relative), contents);

  /// Returns the relative key. Avatars and covers are read back as bytes.
  Future<String> writeBytes(String relative, Uint8List bytes) async {
    await _box.put(_key(relative), base64Encode(bytes));
    return relative;
  }

  Future<String?> readString(String relative) async => _box.get(_key(relative));

  Future<Uint8List?> readBytes(String relative) async {
    final raw = _box.get(_key(relative));
    if (raw == null) return null;
    try {
      return base64Decode(raw);
    } on FormatException {
      return null;
    }
  }

  Future<bool> exists(String relative) async => _box.containsKey(_key(relative));

  Future<void> delete(String? relative) async {
    if (relative == null) return;
    await _box.delete(_key(relative));
  }

  Future<void> deleteAll() async {
    final prefix = '$_prefix/';
    final keys = _box.keys.whereType<String>().where((key) => key.startsWith(prefix)).toList();
    await _box.deleteAll(keys);
  }
}
