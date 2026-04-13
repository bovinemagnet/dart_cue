/// Tests for hostile / malformed CUE input. The parser is intentionally
/// permissive: it must never throw, and it should preserve as much valid
/// data as possible while silently dropping unparseable fragments.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_cue/dart_cue.dart';
import 'package:test/test.dart';

void main() {
  group('parseCueSheet — malformed MSF timestamps', () {
    test('INDEX with bad frame count is dropped, track survives', () {
      const cue = '''
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    TITLE "Bad Index"
    INDEX 01 00:00:99
''';
      final sheet = parseCueSheet(cue)!;
      final track = sheet.files[0].tracks[0];
      expect(track.title, 'Bad Index');
      expect(track.indices.containsKey(1), isFalse);
      expect(track.startTime, isNull);
    });

    test('INDEX with non-numeric timestamp is dropped', () {
      const cue = '''
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    INDEX 01 aa:bb:cc
''';
      final sheet = parseCueSheet(cue)!;
      expect(sheet.files[0].tracks[0].indices, isEmpty);
    });

    test('INDEX with too few colons is dropped', () {
      const cue = '''
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    INDEX 01 01:02
''';
      final sheet = parseCueSheet(cue)!;
      expect(sheet.files[0].tracks[0].indices, isEmpty);
    });

    test('PREGAP / POSTGAP with bad timestamp → null, no crash', () {
      const cue = '''
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    PREGAP not:a:time
    POSTGAP 99:99:99
    INDEX 01 00:00:00
''';
      final sheet = parseCueSheet(cue)!;
      final track = sheet.files[0].tracks[0];
      expect(track.pregap, isNull);
      expect(track.postgap, isNull);
      expect(track.startTime, isNotNull);
    });
  });

  group('parseCueSheet — out-of-place commands', () {
    test('INDEX before any TRACK is ignored', () {
      const cue = '''
INDEX 01 00:00:00
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    INDEX 01 00:00:00
''';
      final sheet = parseCueSheet(cue)!;
      expect(sheet.files.length, 1);
      expect(sheet.files[0].tracks[0].startTime, Duration.zero);
    });

    test('TRACK without preceding FILE still captured', () {
      const cue = '''
TRACK 01 AUDIO
  TITLE "Orphan"
  INDEX 01 00:00:00
''';
      final sheet = parseCueSheet(cue)!;
      expect(sheet.files.length, 1);
      expect(sheet.files[0].filename, '');
      expect(sheet.files[0].tracks[0].title, 'Orphan');
    });

    test('FLAGS / ISRC / PREGAP outside a track are ignored', () {
      const cue = '''
FLAGS DCP
ISRC ZZABC1234567
PREGAP 00:01:00
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    INDEX 01 00:00:00
''';
      expect(() => parseCueSheet(cue), returnsNormally);
      final sheet = parseCueSheet(cue)!;
      expect(sheet.files[0].tracks[0].isrc, isNull);
      expect(sheet.files[0].tracks[0].pregap, isNull);
      expect(sheet.files[0].tracks[0].flags, isEmpty);
    });
  });

  group('parseCueSheet — malformed command syntax', () {
    test('FILE without type is ignored', () {
      const cue = '''
FILE "a.wav"
  TRACK 01 AUDIO
    INDEX 01 00:00:00
''';
      final sheet = parseCueSheet(cue);
      expect(sheet, isNotNull);
      // The FILE line didn't match, so filename falls back to empty.
      expect(sheet!.files[0].filename, '');
    });

    test('TRACK with non-numeric number is ignored', () {
      const cue = '''
FILE "a.wav" WAVE
  TRACK XX AUDIO
    INDEX 01 00:00:00
  TRACK 02 AUDIO
    INDEX 01 01:00:00
''';
      final sheet = parseCueSheet(cue)!;
      // Only the valid TRACK 02 should have been captured.
      expect(sheet.files[0].tracks.length, 1);
      expect(sheet.files[0].tracks[0].trackNumber, 2);
    });

    test('FLAGS with unknown tokens keeps the known ones', () {
      const cue = '''
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    FLAGS DCP BOGUS PRE WEIRD
    INDEX 01 00:00:00
''';
      final sheet = parseCueSheet(cue)!;
      expect(sheet.files[0].tracks[0].flags,
          containsAll([CueFlag.dcp, CueFlag.preEmphasis]));
    });

    test('unknown file type silently defaults to WAVE', () {
      const cue = 'FILE "a.xyz" XYZ\n  TRACK 01 AUDIO\n    INDEX 01 00:00:00\n';
      expect(parseCueSheet(cue)!.files[0].fileType, CueFileType.wave);
    });

    test('unknown track type silently defaults to AUDIO', () {
      const cue =
          'FILE "a.wav" WAVE\n  TRACK 01 WEIRD\n    INDEX 01 00:00:00\n';
      expect(
          parseCueSheet(cue)!.files[0].tracks[0].trackType, CueTrackType.audio);
    });

    test('REM with no value stores empty string', () {
      const cue = '''
REM LONELY
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    INDEX 01 00:00:00
''';
      final sheet = parseCueSheet(cue)!;
      expect(sheet.remComments['LONELY'], '');
    });

    test('unclosed quote does not crash; value kept verbatim', () {
      const cue = '''
TITLE "Unterminated
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    INDEX 01 00:00:00
''';
      expect(() => parseCueSheet(cue), returnsNormally);
      final sheet = parseCueSheet(cue)!;
      // Regex _reQuoted requires both quotes — so value is kept unquoted.
      expect(sheet.title, '"Unterminated');
    });
  });

  group('parseCueSheet — structural edge cases', () {
    test('only comments / no FILE → null (no recognisable data)', () {
      const cue = 'REM GENRE Rock\nREM DATE 2024\n';
      expect(parseCueSheet(cue), isNull);
    });

    test('duplicate INDEX number overwrites — last wins, no crash', () {
      const cue = '''
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    INDEX 01 00:00:00
    INDEX 01 01:00:00
''';
      final sheet = parseCueSheet(cue)!;
      expect(sheet.files[0].tracks[0].startTime, Duration(minutes: 1));
    });

    test('duplicate TRACK numbers both preserved', () {
      const cue = '''
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    INDEX 01 00:00:00
  TRACK 01 AUDIO
    INDEX 01 02:00:00
''';
      final sheet = parseCueSheet(cue)!;
      expect(sheet.files[0].tracks.length, 2);
    });

    test('garbage interleaved with valid commands: valid data preserved', () {
      const cue = '''
%%% random noise
TITLE "Survivor"
not a cue command
FILE "a.wav" WAVE
~!@#\$
  TRACK 01 AUDIO
  also garbage
    INDEX 01 00:00:00
''';
      expect(() => parseCueSheet(cue), returnsNormally);
      final sheet = parseCueSheet(cue)!;
      expect(sheet.title, 'Survivor');
      expect(sheet.files[0].tracks[0].startTime, Duration.zero);
    });

    test('very long line does not crash', () {
      final longTitle = 'x' * 10000;
      final cue = 'TITLE "$longTitle"\nFILE "a.wav" WAVE\n'
          '  TRACK 01 AUDIO\n    INDEX 01 00:00:00\n';
      final sheet = parseCueSheet(cue)!;
      expect(sheet.title!.length, 10000);
    });

    test('embedded NUL bytes do not crash', () {
      const cue = 'TITLE "Has\u0000Null"\nFILE "a.wav" WAVE\n'
          '  TRACK 01 AUDIO\n    INDEX 01 00:00:00\n';
      expect(() => parseCueSheet(cue), returnsNormally);
    });
  });

  group('parseCueBytes — hostile byte input', () {
    test('empty byte array → null, no crash', () {
      expect(parseCueBytes(Uint8List(0)), isNull);
    });

    test('pure binary garbage → null or non-crashing result', () {
      final garbage = Uint8List.fromList(List<int>.generate(256, (i) => i));
      expect(() => parseCueBytes(garbage), returnsNormally);
    });

    test('BOM-only file → null', () {
      final bomOnly = Uint8List.fromList(<int>[0xEF, 0xBB, 0xBF]);
      expect(parseCueBytes(bomOnly), isNull);
    });

    test('UTF-16 LE BOM with no content → null', () {
      final bomOnly = Uint8List.fromList(<int>[0xFF, 0xFE]);
      expect(parseCueBytes(bomOnly), isNull);
    });

    test('truncated UTF-16 (odd byte count after BOM) does not crash', () {
      final bytes = Uint8List.fromList(<int>[0xFF, 0xFE, 0x54, 0x00, 0x49]);
      expect(() => parseCueBytes(bytes), returnsNormally);
    });

    test('invalid UTF-8 with high bytes falls back to Latin-1', () {
      final content = utf8.encode('FILE "a.wav" WAVE\n'
          '  TRACK 01 AUDIO\n    INDEX 01 00:00:00\n');
      // Prepend a stray 0xFF which would break a strict UTF-8 decode.
      final bytes = Uint8List.fromList(<int>[0xFF, ...content]);
      expect(() => parseCueBytes(bytes), returnsNormally);
      expect(parseCueBytes(bytes), isNotNull);
    });
  });
}
