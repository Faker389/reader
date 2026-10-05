import 'dart:convert';
import 'dart:typed_data';

/// Decodes text files that may be UTF-8 (with or without BOM), UTF-16, or a
/// legacy single-byte encoding.
String decodeText(Uint8List bytes) {
  if (bytes.length >= 2) {
    if (bytes[0] == 0xFF && bytes[1] == 0xFE) return _utf16(bytes.sublist(2), littleEndian: true);
    if (bytes[0] == 0xFE && bytes[1] == 0xFF) return _utf16(bytes.sublist(2), littleEndian: false);
  }
  var start = 0;
  if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) start = 3;
  final body = start == 0 ? bytes : Uint8List.sublistView(bytes, start);
  try {
    return utf8.decode(body);
  } on FormatException {
    return latin1.decode(body);
  }
}

String _utf16(Uint8List bytes, {required bool littleEndian}) {
  final units = <int>[];
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    units.add(littleEndian ? bytes[i] | (bytes[i + 1] << 8) : (bytes[i] << 8) | bytes[i + 1]);
  }
  return String.fromCharCodes(units);
}

String normaliseLineEndings(String text) => text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
