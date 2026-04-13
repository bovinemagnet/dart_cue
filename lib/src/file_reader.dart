/// File I/O utilities for reading CUE sheets from disk.
///
/// Detects UTF-8, UTF-16 LE and UTF-16 BE byte-order marks. Falls back to
/// UTF-8 then Latin-1 (ISO-8859-1) when no BOM is present — Latin-1 is a
/// common encoding for CUE sheets produced by Windows rippers.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'models.dart';
import 'parser.dart';

/// Parse a CUE sheet from the file at [filePath].
///
/// Returns `null` if the file does not exist or contains no recognisable data.
Future<CueSheet?> parseCueFile(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) return null;
  final bytes = await file.readAsBytes();
  return parseCueBytes(bytes);
}

/// Parse a CUE sheet from raw [bytes].
///
/// Decoding order: byte-order mark detection first (UTF-8, UTF-16 LE, UTF-16
/// BE), then [encoding] (default UTF-8), then Latin-1 as a lossless fallback.
CueSheet? parseCueBytes(Uint8List bytes, {Encoding encoding = utf8}) {
  final content = _decodeWithBom(bytes, encoding);
  return parseCueSheet(content);
}

String _decodeWithBom(Uint8List bytes, Encoding fallback) {
  // UTF-8 BOM: EF BB BF
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3));
  }
  // UTF-16 LE BOM: FF FE
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return _decodeUtf16(bytes.sublist(2), littleEndian: true);
  }
  // UTF-16 BE BOM: FE FF
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return _decodeUtf16(bytes.sublist(2), littleEndian: false);
  }
  // No BOM — try requested encoding, fall back to Latin-1.
  try {
    return fallback.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}

String _decodeUtf16(Uint8List bytes, {required bool littleEndian}) {
  final units = <int>[];
  for (int i = 0; i + 1 < bytes.length; i += 2) {
    final lo = littleEndian ? bytes[i] : bytes[i + 1];
    final hi = littleEndian ? bytes[i + 1] : bytes[i];
    units.add((hi << 8) | lo);
  }
  return String.fromCharCodes(units);
}
