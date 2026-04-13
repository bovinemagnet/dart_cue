/// Filesystem-backed `parseCueFile` for the Dart VM and Flutter
/// (non-web) targets.
library;

import 'dart:io';

import 'file_reader.dart';
import 'models.dart';

/// Parse a CUE sheet from the file at [filePath].
///
/// Returns `null` if the file does not exist or contains no recognisable
/// data. Encoding is auto-detected (UTF-8/UTF-16 BOM; Latin-1 fallback).
Future<CueSheet?> parseCueFile(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) return null;
  final bytes = await file.readAsBytes();
  return parseCueBytes(bytes);
}
