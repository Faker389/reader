import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

  final Directory directory;

  static String contentPath(String bookId) => p.join('books', '$bookId.json');
  static String coverPath(String bookId, String extension) =>
      p.join('covers', '$bookId-${DateTime.now().millisecondsSinceEpoch}.$extension');
  static const String avatarPath = 'avatar';

  File resolve(String relative) => File(p.join(directory.path, relative));

  Future<File> writeString(String relative, String contents) async {
    final file = resolve(relative);
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(contents, flush: true);
    return temp.rename(file.path);
  }

  Future<File> writeBytes(String relative, Uint8List bytes) async {
    final file = resolve(relative);
    await file.parent.create(recursive: true);
    return file.writeAsBytes(bytes, flush: true);
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
