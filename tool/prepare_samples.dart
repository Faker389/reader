// Converts raw Project Gutenberg plain-text downloads (tool/raw/*.txt) into
// the compact sample-book format bundled in assets/books/.
//
// Output format: "# Chapter title" heading lines, paragraphs separated by a
// blank line, one paragraph per line. Gutenberg headers, licence text and
// tables of contents are stripped so only the public-domain work remains.
//
// Usage: dart run tool/prepare_samples.dart
import 'dart:io';

class _Spec {
  const _Spec({
    required this.id,
    required this.startLine,
    required this.endLine,
    required this.heading,
    this.preamble,
    this.skip,
  });

  final String id;

  /// 1-based inclusive start line.
  final int startLine;

  /// 1-based exclusive end line.
  final int endLine;

  /// Returns a chapter title for heading lines, or null for body lines.
  final String? Function(List<String> lines, int index) heading;

  /// Heading inserted before the first line (for works whose first heading
  /// is embedded in illustration markup).
  final String? preamble;

  /// Lines that should be dropped entirely.
  final bool Function(String line)? skip;
}

final _roman = RegExp(r'^[IVXLC]+$');

String _titleCase(String input) {
  const small = {'of', 'the', 'in', 'a', 'an', 'and', 'with'};
  final words = input.toLowerCase().split(RegExp(r'\s+'));
  return [
    for (var i = 0; i < words.length; i++)
      if (i > 0 && small.contains(words[i]))
        words[i]
      else if (words[i].isEmpty)
        words[i]
      else
        words[i][0].toUpperCase() + words[i].substring(1),
  ].join(' ');
}

String? _nextNonEmpty(List<String> lines, int index) {
  for (var i = index + 1; i < lines.length && i < index + 4; i++) {
    if (lines[i].trim().isNotEmpty) return lines[i].trim();
  }
  return null;
}

final specs = <_Spec>[
  _Spec(
    id: 'alice',
    startLine: 58,
    endLine: 3408,
    heading: (lines, i) {
      final m = RegExp(r'^CHAPTER ([IVXL]+)\.$').firstMatch(lines[i].trim());
      if (m == null) return null;
      final subtitle = _nextNonEmpty(lines, i);
      return 'Chapter ${m.group(1)}: $subtitle';
    },
    skip: null,
  ),
  _Spec(
    id: 'pride',
    startLine: 702,
    endLine: 14550,
    preamble: 'Chapter I',
    heading: (lines, i) {
      final m = RegExp(r'^CHAPTER ([IVXLC]+)\.?$').firstMatch(lines[i].trim());
      return m == null ? null : 'Chapter ${m.group(1)}';
    },
  ),
  _Spec(
    id: 'sherlock',
    startLine: 55,
    endLine: 11960,
    heading: (lines, i) {
      final m = RegExp(r'^[IVX]+\. ([A-Z].+)$').firstMatch(lines[i].trim());
      if (m == null) return null;
      final title = m.group(1)!;
      return title == title.toUpperCase() ? _titleCase(title) : null;
    },
    skip: (line) => RegExp(r'^[IVX]+\.$').hasMatch(line.trim()),
  ),
  _Spec(
    id: 'meditations',
    startLine: 579,
    endLine: 5737,
    heading: (lines, i) {
      final m = RegExp(r'^THE ([A-Z]+) BOOK$').firstMatch(lines[i].trim());
      return m == null ? null : _titleCase('The ${m.group(1)} Book');
    },
  ),
  _Spec(
    id: 'gatsby',
    startLine: 63,
    endLine: 6435,
    heading: (lines, i) {
      final raw = lines[i];
      final trimmed = raw.trim();
      if (!raw.startsWith('   ') || !_roman.hasMatch(trimmed)) return null;
      return 'Chapter $trimmed';
    },
  ),
];

void main() {
  final outDir = Directory('assets/books')..createSync(recursive: true);
  for (final spec in specs) {
    final lines = File('tool/raw/${spec.id}.txt').readAsLinesSync();
    final out = StringBuffer();
    final paragraph = <String>[];
    var inIllustration = false;
    String? pendingSubtitleSkip;

    void flush() {
      if (paragraph.isEmpty) return;
      out
        ..writeln(paragraph.join(' ').replaceAll('_', '').trim())
        ..writeln();
      paragraph.clear();
    }

    if (spec.preamble != null) {
      out
        ..writeln('# ${spec.preamble}')
        ..writeln();
    }

    for (var i = spec.startLine - 1; i < spec.endLine - 1; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (inIllustration) {
        if (trimmed.contains(']')) inIllustration = false;
        continue;
      }
      if (trimmed.startsWith('[Illustration')) {
        if (!trimmed.contains(']')) inIllustration = true;
        continue;
      }
      if (pendingSubtitleSkip != null && trimmed == pendingSubtitleSkip) {
        pendingSubtitleSkip = null;
        continue;
      }
      if (spec.skip?.call(line) ?? false) continue;

      final title = spec.heading(lines, i);
      if (title != null) {
        flush();
        out
          ..writeln('# $title')
          ..writeln();
        if (spec.id == 'alice') pendingSubtitleSkip = _nextNonEmpty(lines, i);
        continue;
      }

      if (trimmed.isEmpty) {
        flush();
      } else {
        pendingSubtitleSkip = null;
        paragraph.add(trimmed);
      }
    }
    flush();

    final file = File('${outDir.path}/${spec.id}.txt')
      ..writeAsStringSync(out.toString().trim());
    final words = out.toString().split(RegExp(r'\s+')).length;
    stdout.writeln('${spec.id}: ${file.lengthSync()} bytes, ~$words words');
  }
}
