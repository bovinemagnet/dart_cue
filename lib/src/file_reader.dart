/// File I/O utilities for reading CUE sheets from disk.
///
/// Tries UTF-8 first, falls back to Latin-1 (ISO-8859-1) — a common encoding
/// for CUE sheets produced by Windows rippers.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'models.dart';
import 'parser.dart';

/// Parse a CUE sheet from the file at [filePath].
///
/// Tries UTF-8 decoding first; on a [FormatException] falls back to Latin-1.
/// Returns `null` if the file does not exist or contains no recognisable data.
Future<CueSheet?> parseCueFile(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) return null;
  final bytes = await file.readAsBytes();
  return parseCueBytes(bytes);
}

/// Parse a CUE sheet from raw [bytes].
///
/// [encoding] defaults to UTF-8. If UTF-8 decoding fails (throws a
/// [FormatException]) the function automatically retries with Latin-1.
CueSheet? parseCueBytes(Uint8List bytes, {Encoding encoding = utf8}) {
  String content;
  try {
    content = encoding.decode(bytes);
  } on FormatException {
    // Fall back to Latin-1 (lossless for any byte sequence).
    content = latin1.decode(bytes);
  }
  return parseCueSheet(content);
}
