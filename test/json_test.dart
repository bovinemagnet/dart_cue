/// Tests for `toJson` / `fromJson` on the model classes.
library;

import 'dart:convert';

import 'package:dart_cue/dart_cue.dart';
import 'package:test/test.dart';

const _cue = '''
CATALOG 1234567890123
PERFORMER "Artist"
TITLE "Album"
SONGWRITER "Writer"
CDTEXTFILE "cd.cdt"
REM GENRE Rock
REM DATE 2024
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    TITLE "One"
    PERFORMER "Solo"
    ISRC USABC1234567
    FLAGS DCP PRE
    PREGAP 00:02:00
    REM REPLAYGAIN_TRACK_GAIN -6 dB
    INDEX 00 00:00:00
    INDEX 01 00:02:00
    POSTGAP 00:00:10
  TRACK 02 AUDIO
    TITLE "Two"
    INDEX 01 04:15:25
FILE "b.wav" WAVE
  TRACK 03 AUDIO
    TITLE "Three"
    INDEX 01 00:00:00
''';

void main() {
  group('round-trip through JSON', () {
    test('parsed sheet → toJson → fromJson equals original', () {
      final original = parseCueSheet(_cue)!;
      final json = original.toJson();
      final restored = CueSheet.fromJson(json);
      expect(restored, equals(original));
    });

    test('result is actually encodable as JSON text', () {
      final original = parseCueSheet(_cue)!;
      final text = jsonEncode(original.toJson());
      final decoded = jsonDecode(text) as Map<String, Object?>;
      final restored = CueSheet.fromJson(decoded);
      expect(restored, equals(original));
    });

    test('hand-built sheet round-trips', () {
      final built = CueSheet(
        title: 'Built',
        files: [
          CueFile(
            filename: 'x.wav',
            fileType: CueFileType.wave,
            tracks: [
              CueTrack(
                trackNumber: 1,
                trackType: CueTrackType.audio,
                title: 'T',
                flags: {CueFlag.dcp},
                indices: {1: Duration.zero},
                remComments: {'K': 'v'},
              ),
            ],
          ),
        ],
        remComments: {'GENRE': 'Jazz'},
      );
      final restored = CueSheet.fromJson(built.toJson());
      expect(restored, equals(built));
    });

    test('CueTrack endTime survives round-trip', () {
      final track = CueTrack(
        trackNumber: 1,
        trackType: CueTrackType.audio,
        indices: {1: Duration.zero},
      );
      track.endTime = parseMsf('03:00:00');
      final restored = CueTrack.fromJson(track.toJson());
      expect(restored.endTime, parseMsf('03:00:00'));
    });
  });

  group('JSON shape', () {
    late Map<String, Object?> json;
    setUp(() => json = parseCueSheet(_cue)!.toJson());

    test('top-level scalar fields present when set', () {
      expect(json['title'], 'Album');
      expect(json['performer'], 'Artist');
      expect(json['catalog'], '1234567890123');
    });

    test('files is a list with two entries', () {
      expect(json['files'], isA<List<Object?>>());
      expect((json['files']! as List).length, 2);
    });

    test('track flags is a list of CUE tokens', () {
      final t1 = ((json['files']! as List)[0] as Map)['tracks'][0]
          as Map<String, Object?>;
      expect(t1['flags'], containsAll(<Object>['DCP', 'PRE']));
    });

    test('indices map has stringified integer keys and MSF values', () {
      final t1 = ((json['files']! as List)[0] as Map)['tracks'][0]
          as Map<String, Object?>;
      final indices = t1['indices']! as Map<String, Object?>;
      expect(indices['0'], '00:00:00');
      expect(indices['1'], '00:02:00');
    });

    test('track-level remComments present', () {
      final t1 = ((json['files']! as List)[0] as Map)['tracks'][0]
          as Map<String, Object?>;
      expect(t1['remComments'], {'REPLAYGAIN_TRACK_GAIN': '-6 dB'});
    });

    test('null fields are omitted', () {
      final t2 = ((json['files']! as List)[0] as Map)['tracks'][1]
          as Map<String, Object?>;
      expect(t2.containsKey('performer'), isFalse);
      expect(t2.containsKey('isrc'), isFalse);
      expect(t2.containsKey('pregap'), isFalse);
    });
  });

  group('fromJson tolerance', () {
    test('accepts a minimal map', () {
      final sheet = CueSheet.fromJson({'files': []});
      expect(sheet.files, isEmpty);
      expect(sheet.title, isNull);
    });

    test('accepts a track with only required fields', () {
      final t = CueTrack.fromJson({
        'trackNumber': 1,
        'trackType': 'AUDIO',
      });
      expect(t.trackNumber, 1);
      expect(t.trackType, CueTrackType.audio);
      expect(t.flags, isEmpty);
      expect(t.indices, isEmpty);
    });

    test('CueFile.fromJson accepts an empty tracks list', () {
      final f = CueFile.fromJson({
        'filename': 'x.wav',
        'fileType': 'WAVE',
        'tracks': <Object?>[],
      });
      expect(f.tracks, isEmpty);
    });
  });
}
