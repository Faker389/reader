import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'file_locations.dart';
import 'local_database.dart';

/// Device file storage for book text and cover images. Files are kept in the
/// app's private documents directory and never leave the device.
class FileStore {
  FileStore._(this.root);

  static Future<FileStore> open() async {
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(docs.path, 'fovea'));
    await root.create(recursive: true);
    return FileStore._(root);
  }

  final Directory root;

  UserFiles forUser(String uid) =>
      UserFiles(Directory(p.join(root.path, 'users', LocalDatabase.scopeKey(uid))));
}

class UserFiles {
  UserFiles(this.directory);

  static String contentPath(String bookId) => FileLocations.contentPath(bookId);
  static String coverPath(String bookId, String extension) => FileLocations.coverPath(bookId, extension);
  static const String avatarPath = FileLocations.avatarPath;

  final Directory directory;

  File resolve(String relative) => File(p.join(directory.path, relative));

  /// Absolute path for widgets that render with [FileImage]. Null is never
  /// returned here; the browser store has no filesystem.
  String? filesystemPath(String relative) => resolve(relative).path;

  Future<void> writeString(String relative, String contents) async {
    final file = resolve(relative);
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(contents, flush: true);
    await temp.rename(file.path);
  }

  /// Returns the absolute path, which is what the profile stores for avatars.
  Future<String> writeBytes(String relative, Uint8List bytes) async {
    final file = resolve(relative);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<String?> readString(String relative) async {
    final file = resolve(relative);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  Future<Uint8List?> readBytes(String relative) async {
    final file = resolve(relative);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<bool> exists(String relative) => resolve(relative).exists();

  Future<void> delete(String? relative) async {
    if (relative == null) return;
    final file = resolve(relative);
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteAll() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
