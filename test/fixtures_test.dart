/// End-to-end tests against canonical `.cue` fixtures representing the
/// styles produced by real-world tools (EAC, cdrdao, per-track WAV rippers)
/// and edge layouts (hidden pre-gap track). These double as executable
/// documentation of what the library promises to handle.
library;

import 'dart:io';

import 'package:dart_cue/dart_cue.dart';
import 'package:test/test.dart';

CueSheet _load(String name) {
  final path = '${Directory.current.path}/test/fixtures/$name';
  final content = File(path).readAsStringSync();
  final sheet = parseCueSheet(content);
  if (sheet == null) fail('fixture $name failed to parse');
  return sheet;
}

void main() {
  group('EAC-style single-file rip', () {
    late CueSheet sheet;
    setUp(() => sheet = _load('eac.cue'));

    test('album metadata', () {
      expect(sheet.performer, 'Fictional Band');
      expect(sheet.title, 'Imaginary Album');
      expect(sheet.catalog, '0724384974923');
      expect(sheet.genre, 'Alternative Rock');
      expect(sheet.date, '1997');
      expect(sheet.discId, 'A20B3C04');
      expect(sheet.remComments['COMMENT'], 'ExactAudioCopy v1.3');
    });

    test('single FILE with quoted filename containing spaces', () {
      expect(sheet.files.length, 1);
      expect(sheet.files[0].filename, 'Fictional Band - Imaginary Album.wav');
      expect(sheet.files[0].fileType, CueFileType.wave);
    });

    test('four tracks with ISRCs, INDEX 00 pregaps and ISRCs round-trip', () {
      final tracks = sheet.files[0].tracks;
      expect(tracks.length, 4);
      expect(tracks.map((t) => t.isrc).whereType<String>().length, 4);
      // INDEX 00 present from track 02 onwards (physical pregap in the image).
      expect(tracks[1].indices.containsKey(0), isTrue);
      expect(tracks[2].indices.containsKey(0), isTrue);
      expect(tracks[3].indices.containsKey(0), isTrue);
    });

    test('derived endTime/duration chain', () {
      final tracks = sheet.files[0].tracks;
      expect(tracks[0].endTime, tracks[1].startTime);
      expect(tracks[1].duration, isNotNull);
      expect(tracks.last.endTime, isNull);
    });

    test('round-trips byte-identical in structure', () {
      final reparsed = parseCueSheet(toCueString(sheet))!;
      expect(reparsed.title, sheet.title);
      expect(reparsed.files[0].tracks.length, 4);
      for (var i = 0; i < 4; i++) {
        expect(reparsed.files[0].tracks[i].isrc, sheet.files[0].tracks[i].isrc);
        expect(reparsed.files[0].tracks[i].startTime,
            sheet.files[0].tracks[i].startTime);
      }
    });
  });

  group('cdrdao-style BINARY image with mixed track types', () {
    late CueSheet sheet;
    setUp(() => sheet = _load('cdrdao.cue'));

    test('BINARY file type detected', () {
      expect(sheet.files[0].fileType, CueFileType.binary);
    });

    test('mixed MODE1/2352 and AUDIO tracks', () {
      final types = sheet.files[0].tracks.map((t) => t.trackType).toList();
      expect(types, contains(CueTrackType.mode1_2352));
      expect(types, contains(CueTrackType.audio));
    });

    test('FLAGS survive', () {
      for (final t in sheet.files[0].tracks) {
        expect(t.flags.contains(CueFlag.dcp), isTrue);
      }
      expect(
          sheet.files[0].tracks[2].flags.contains(CueFlag.preEmphasis), isTrue);
    });

    test('PREGAP captured on data→audio transition', () {
      expect(sheet.files[0].tracks[1].pregap, parseMsf('00:02:00'));
    });
  });

  group('Per-track WAV album (multi-file)', () {
    late CueSheet sheet;
    setUp(() => sheet = _load('multi_file.cue'));

    test('three FILE blocks, one track each', () {
      expect(sheet.files.length, 3);
      for (final f in sheet.files) {
        expect(f.tracks.length, 1);
        expect(f.tracks[0].startTime, Duration.zero);
      }
    });

    test('track numbers continue across FILE blocks', () {
      final numbers = [
        for (final f in sheet.files)
          for (final t in f.tracks) t.trackNumber,
      ];
      expect(numbers, [1, 2, 3]);
    });

    test('per-track performers preserved', () {
      expect(sheet.files[0].tracks[0].performer, 'Orchestra A');
      expect(sheet.files[1].tracks[0].performer, 'Orchestra B');
    });

    test('endTime is null on every track (each file is self-contained)', () {
      for (final f in sheet.files) {
        expect(f.tracks[0].endTime, isNull);
      }
    });
  });

  group('Hidden pre-gap track', () {
    late CueSheet sheet;
    setUp(() => sheet = _load('hidden_track.cue'));

    test('INDEX 00 on track 01 is captured', () {
      final t1 = sheet.files[0].tracks[0];
      expect(t1.indices[0], Duration.zero);
      expect(t1.startTime, parseMsf('00:30:00'));
    });

    test('sheet round-trips losslessly', () {
      final reparsed = parseCueSheet(toCueString(sheet))!;
      final t1 = reparsed.files[0].tracks[0];
      expect(t1.indices[0], Duration.zero);
      expect(t1.indices[1], parseMsf('00:30:00'));
    });
  });
}
