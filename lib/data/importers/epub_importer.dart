import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_failure.dart';
import '../../core/utils/sanitize.dart';
import '../../domain/models/book.dart';
import '../../domain/models/book_content.dart';
import 'book_importer.dart';

/// EPUB 2/3. Reads the OPF package for metadata and reading order, the nav
/// document or NCX for chapter titles, and converts XHTML into paragraphs.
class EpubImporter implements BookImporter {
  const EpubImporter();

  static const Set<String> _blockTags = {
    'p', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'li', 'blockquote', 'pre',
    'section', 'article', 'header', 'footer', 'aside', 'dd', 'dt', 'figcaption',
    'td', 'th', 'tr', 'table', 'ul', 'ol', 'dl', 'body', 'main', 'nav', 'hr',
  };
  static const Set<String> _skipTags = {'script', 'style', 'head', 'svg', 'math', 'title'};
  static const Set<String> _headingTags = {'h1', 'h2', 'h3'};

  @override
  Set<String> get extensions => const {'epub'};

  @override
  BookFormat get format => BookFormat.epub;

  @override
  bool get isAvailable => true;

  @override
  ParsedBook parse(Uint8List bytes, {required String fileName}) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } on Object catch (e) {
      throw ImportException(ImportErrorType.corruptedEpub, '$e');
    }

    if (archive.findFile('META-INF/encryption.xml') != null && _hasContentEncryption(archive)) {
      throw const ImportException(ImportErrorType.drmProtected);
    }

    final opfPath = _rootFilePath(archive);
    final opf = _parseXml(_readString(archive, opfPath));
    if (opf == null) throw const ImportException(ImportErrorType.corruptedEpub, 'Invalid OPF');
    final opfDir = p.posix.dirname(opfPath);

    final title = _firstText(opf, 'title') ?? titleFromFileName(fileName);
    final author = _firstText(opf, 'creator') ?? '';

    final manifest = <String, _ManifestItem>{};
    for (final item in opf.findAllElements('item', namespace: '*')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id == null || href == null) continue;
      manifest[id] = _ManifestItem(
        path: _resolve(opfDir, href),
        mediaType: item.getAttribute('media-type') ?? '',
        properties: item.getAttribute('properties') ?? '',
      );
    }

    final spine = opf.findAllElements('spine', namespace: '*').firstOrNull;
    if (spine == null) throw const ImportException(ImportErrorType.corruptedEpub, 'No spine');
    final tocTitles = _tocTitles(archive, opf, manifest, spine);

    final chapters = <ParsedChapter>[];
    for (final itemRef in spine.findElements('itemref', namespace: '*')) {
      if (itemRef.getAttribute('linear') == 'no') continue;
      final item = manifest[itemRef.getAttribute('idref')];
      if (item == null || !item.mediaType.contains('html')) continue;
      final source = _tryReadString(archive, item.path);
      if (source == null) continue;
      final extracted = _extract(source);
      final chapter = ParsedChapter(
        title: Sanitize.line(
          tocTitles[item.path] ?? extracted.heading ?? 'Chapter ${chapters.length + 1}',
          maxLength: ImportConstants.maxChapterTitleLength,
        ),
        paragraphs: extracted.paragraphs,
      );
      if (chapter.wordCount >= ImportConstants.minChapterWords) chapters.add(chapter);
    }

    if (chapters.isEmpty) throw const ImportException(ImportErrorType.emptyBook);

    final cover = _cover(archive, opf, manifest);
    return ParsedBook(
      title: Sanitize.line(title, maxLength: ImportConstants.maxTitleLength),
      author: Sanitize.line(author, maxLength: ImportConstants.maxAuthorLength),
      chapters: chapters,
      coverBytes: cover?.$1,
      coverExtension: cover?.$2,
    );
  }

  // --- structure ------------------------------------------------------------

  String _rootFilePath(Archive archive) {
    final container = _parseXml(_tryReadString(archive, 'META-INF/container.xml') ?? '');
    final path = container
        ?.findAllElements('rootfile', namespace: '*')
        .map((e) => e.getAttribute('full-path'))
        .whereType<String>()
        .firstOrNull;
    if (path != null && archive.findFile(path) != null) return path;
    // Some malformed books omit container.xml; fall back to the first OPF.
    for (final file in archive) {
      if (file.isFile && file.name.toLowerCase().endsWith('.opf')) return file.name;
    }
    throw const ImportException(ImportErrorType.corruptedEpub, 'No package document');
  }

  bool _hasContentEncryption(Archive archive) {
    final xml = _parseXml(_tryReadString(archive, 'META-INF/encryption.xml') ?? '');
    if (xml == null) return false;
    // Font obfuscation is common and harmless; anything else means DRM.
    for (final method in xml.findAllElements('EncryptionMethod', namespace: '*')) {
      final algorithm = method.getAttribute('Algorithm') ?? '';
      if (!algorithm.contains('font') && !algorithm.contains('obfuscation')) return true;
    }
    return false;
  }

  Map<String, String> _tocTitles(
    Archive archive,
    XmlDocument opf,
    Map<String, _ManifestItem> manifest,
    XmlElement spine,
  ) {
    final titles = <String, String>{};

    final nav = manifest.values.where((m) => m.properties.contains('nav')).firstOrNull;
    if (nav != null) {
      final doc = _parseXml(_tryReadString(archive, nav.path) ?? '');
      final navDir = p.posix.dirname(nav.path);
      for (final link in doc?.findAllElements('a', namespace: '*') ?? const <XmlElement>[]) {
        final href = link.getAttribute('href');
        final text = _normalise(link.innerText);
        if (href == null || text.isEmpty) continue;
        titles.putIfAbsent(_resolve(navDir, href.split('#').first), () => text);
      }
    }

    final ncxId = spine.getAttribute('toc');
    final ncx = (ncxId != null ? manifest[ncxId] : null) ??
        manifest.values.where((m) => m.mediaType == 'application/x-dtbncx+xml').firstOrNull;
    if (ncx != null) {
      final doc = _parseXml(_tryReadString(archive, ncx.path) ?? '');
      final ncxDir = p.posix.dirname(ncx.path);
      for (final point in doc?.findAllElements('navPoint', namespace: '*') ?? const <XmlElement>[]) {
        final label = point.findElements('navLabel', namespace: '*').firstOrNull?.innerText;
        final src = point.findElements('content', namespace: '*').firstOrNull?.getAttribute('src');
        if (label == null || src == null) continue;
        final text = _normalise(label);
        if (text.isNotEmpty) titles.putIfAbsent(_resolve(ncxDir, src.split('#').first), () => text);
      }
    }
    return titles;
  }

  (Uint8List, String)? _cover(Archive archive, XmlDocument opf, Map<String, _ManifestItem> manifest) {
    _ManifestItem? item = manifest.values.where((m) => m.properties.contains('cover-image')).firstOrNull;
    if (item == null) {
      final coverId = opf
          .findAllElements('meta', namespace: '*')
          .where((m) => m.getAttribute('name') == 'cover')
          .map((m) => m.getAttribute('content'))
          .firstOrNull;
      if (coverId != null) item = manifest[coverId];
    }
    item ??= manifest.entries
        .where((e) => e.value.mediaType.startsWith('image/') && e.key.toLowerCase().contains('cover'))
        .map((e) => e.value)
        .firstOrNull;
    if (item == null || !item.mediaType.startsWith('image/')) return null;
    final file = archive.findFile(item.path);
    if (file == null) return null;
    final ext = switch (item.mediaType) {
      'image/png' => 'png',
      'image/gif' => 'gif',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    return (file.content, ext);
  }

  // --- XHTML → paragraphs ------------------------------------------------------

  _Extracted _extract(String source) {
    final doc = _parseXml(source);
    if (doc == null) return _extractWithoutParser(source);
    final body = doc.findAllElements('body', namespace: '*').firstOrNull ?? doc.rootElement;
    final paragraphs = <String>[];
    String? heading;
    final buffer = StringBuffer();

    void flush() {
      final text = _normalise(buffer.toString());
      if (text.isNotEmpty) paragraphs.add(text);
      buffer.clear();
    }

    void visit(XmlNode node) {
      if (node is XmlText || node is XmlCDATA) {
        buffer.write(node.value ?? '');
        return;
      }
      if (node is! XmlElement) return;
      final tag = node.localName.toLowerCase();
      if (_skipTags.contains(tag)) return;
      if (tag == 'br') {
        buffer.write(' ');
        return;
      }
      final isBlock = _blockTags.contains(tag);
      if (isBlock) flush();
      if (heading == null && _headingTags.contains(tag)) {
        final text = _normalise(node.innerText);
        if (text.isNotEmpty) heading = text;
      }
      for (final child in node.children) {
        visit(child);
      }
      if (isBlock) flush();
    }

    visit(body);
    flush();
    return _Extracted(paragraphs, heading);
  }

  static final RegExp _blockBoundary =
      RegExp(r'</(p|div|h[1-6]|li|blockquote|section|tr)>|<br\s*/?>', caseSensitive: false);
  static final RegExp _tag = RegExp(r'<[^>]+>');
  static final RegExp _headBlock =
      RegExp(r'<(head|script|style)[^>]*>.*?</\1>', caseSensitive: false, dotAll: true);

  _Extracted _extractWithoutParser(String source) {
    final withoutHead = source.replaceAll(_headBlock, ' ');
    final paragraphs = withoutHead
        .split(_blockBoundary)
        .map((chunk) => _normalise(_decodeEntities(chunk.replaceAll(_tag, ' '))))
        .where((t) => t.isNotEmpty)
        .toList();
    return _Extracted(paragraphs, null);
  }

  // --- helpers -----------------------------------------------------------------

  XmlDocument? _parseXml(String source) {
    if (source.isEmpty) return null;
    try {
      return XmlDocument.parse(source, entityMapping: const XmlDefaultEntityMapping.html5());
    } on Object {
      return null;
    }
  }

  String? _firstText(XmlDocument doc, String localName) {
    for (final element in doc.findAllElements(localName, namespace: '*')) {
      final text = _normalise(element.innerText);
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  String _readString(Archive archive, String path) {
    final value = _tryReadString(archive, path);
    if (value == null) throw ImportException(ImportErrorType.corruptedEpub, 'Missing $path');
    return value;
  }

  String? _tryReadString(Archive archive, String path) {
    final file = archive.findFile(path) ?? archive.findFile(Uri.decodeFull(path));
    if (file == null) return null;
    try {
      return utf8.decode(file.content, allowMalformed: true);
    } on Object {
      return null;
    }
  }

  String _resolve(String base, String href) {
    final decoded = Uri.decodeFull(href);
    final joined = base == '.' || base.isEmpty ? decoded : p.posix.join(base, decoded);
    return p.posix.normalize(joined);
  }

  static final RegExp _whitespace = RegExp(r'[\s\u00A0]+');

  String _normalise(String text) => Sanitize.text(text.replaceAll(_whitespace, ' '));

  String _decodeEntities(String text) {
    try {
      return const XmlDefaultEntityMapping.html5().decode(text);
    } on Object {
      return text;
    }
  }
}

class _ManifestItem {
  const _ManifestItem({required this.path, required this.mediaType, required this.properties});

  final String path;
  final String mediaType;
  final String properties;
}

class _Extracted {
  const _Extracted(this.paragraphs, this.heading);

  final List<String> paragraphs;
  final String? heading;
}
