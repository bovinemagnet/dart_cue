import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_cue/dart_cue.dart';
import 'package:test/test.dart';

void main() {
  group('parseCueFile', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('dart_cue_test_');
    });

    tearDown(() async {
      await tmpDir.delete(recursive: true);
    });

    test('parses UTF-8 file', () async {
      const content = '''
PERFORMER "UTF-8 Artíst"
TITLE "UTF-8 Album"
FILE "album.wav" WAVE
  TRACK 01 AUDIO
    TITLE "Première"
    INDEX 01 00:00:00
''';
      final file = File('${tmpDir.path}/test.cue');
      await file.writeAsString(content, encoding: const Utf8Codec());
      final sheet = await parseCueFile(file.path);
      expect(sheet, isNotNull);
      expect(sheet!.performer, 'UTF-8 Artíst');
      expect(sheet.files[0].tracks[0].title, 'Première');
    });

    test('parses Latin-1 file', () async {
      // Write bytes directly to simulate a Latin-1 encoded file.
      // 'ä' = 0xE4 in Latin-1.
      final bytes = Uint8List.fromList(
          'PERFORMER "K\xe4nstler"\nFILE "a.wav" WAVE\n  TRACK 01 AUDIO\n    INDEX 01 00:00:00\n'
              .codeUnits);
      final file = File('${tmpDir.path}/latin1.cue');
      await file.writeAsBytes(bytes);
      final sheet = await parseCueFile(file.path);
      expect(sheet, isNotNull);
      // Latin-1 'ä' (0xE4) should survive — decoded via latin1 fallback.
      expect(sheet!.performer, contains('nstler'));
    });

    test('returns null for non-existent file', () async {
      final sheet = await parseCueFile('${tmpDir.path}/nonexistent.cue');
      expect(sheet, isNull);
    });
  });

  group('parseCueBytes', () {
    test('parses UTF-8 bytes', () {
      const content = 'TITLE "Bytes Album"\nFILE "a.wav" WAVE\n  TRACK 01 AUDIO\n    INDEX 01 00:00:00\n';
      final bytes = Uint8List.fromList(content.codeUnits);
      final sheet = parseCueBytes(bytes);
      expect(sheet, isNotNull);
      expect(sheet!.title, 'Bytes Album');
    });

    test('falls back to Latin-1 on invalid UTF-8', () {
      // 0xFF is not valid UTF-8.
      final bytes = Uint8List.fromList(
          'TITLE "Artist \xff"\nFILE "a.wav" WAVE\n  TRACK 01 AUDIO\n    INDEX 01 00:00:00\n'
              .codeUnits);
      // Should not throw.
      expect(() => parseCueBytes(bytes), returnsNormally);
    });
  });
}
