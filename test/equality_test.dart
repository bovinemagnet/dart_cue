/// Value-equality contract for the model classes.
///
/// Two sheets with identical content compare equal regardless of identity,
/// which lets consumers use them in `expect(equals(...))`, put them in
/// `Set`s, and key `Map`s by their content.
library;

import 'package:dart_cue/dart_cue.dart';
import 'package:test/test.dart';

const _sampleCue = '''
CATALOG 1234567890123
PERFORMER "The Artist"
TITLE "Great Album"
REM GENRE Rock
REM DATE 2024
FILE "album.wav" WAVE
  TRACK 01 AUDIO
    TITLE "One"
    PERFORMER "Solo"
    ISRC USABC1234567
    FLAGS DCP PRE
    PREGAP 00:02:00
    REM REPLAYGAIN_TRACK_GAIN -6 dB
    INDEX 00 00:00:00
    INDEX 01 00:02:00
  TRACK 02 AUDIO
    TITLE "Two"
    INDEX 01 04:15:25
''';

void main() {
  group('CueSheet equality', () {
    test('two parses of the same text are equal and have equal hashCodes', () {
      final a = parseCueSheet(_sampleCue)!;
      final b = parseCueSheet(_sampleCue)!;
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('identical reference is equal', () {
      final a = parseCueSheet(_sampleCue)!;
      expect(a, equals(a));
    });

    test('differs when album-level field changes', () {
      final a = parseCueSheet(_sampleCue)!;
      final b = parseCueSheet(
          _sampleCue.replaceAll('TITLE "Great Album"', 'TITLE "Other Album"'))!;
      expect(a, isNot(equals(b)));
    });

    test('differs when an album REM field changes', () {
      final a = parseCueSheet(_sampleCue)!;
      final b = parseCueSheet(
          _sampleCue.replaceAll('REM GENRE Rock', 'REM GENRE Jazz'))!;
      expect(a, isNot(equals(b)));
    });

    test('differs when an album REM field is added', () {
      final a = parseCueSheet(_sampleCue)!;
      final b = parseCueSheet('REM EXTRA foo\n$_sampleCue')!;
      expect(a, isNot(equals(b)));
    });

    test('hand-built sheet equals the re-parse of its toCueString output', () {
      final built = CueSheet(
        performer: 'Built',
        title: 'Built Album',
        catalog: '1234567890123',
        remComments: {'GENRE': 'Jazz'},
        files: [
          CueFile(
            filename: 'a.wav',
            fileType: CueFileType.wave,
            tracks: [
              CueTrack(
                trackNumber: 1,
                trackType: CueTrackType.audio,
                title: 'First',
                indices: {1: parseMsf('00:00:00')!},
              ),
              CueTrack(
                trackNumber: 2,
                trackType: CueTrackType.audio,
                title: 'Second',
                indices: {1: parseMsf('03:00:00')!},
              ),
            ],
          ),
        ],
      );
      // Parser derives endTime on non-last tracks; pin that on the built
      // sheet so equality holds across the round-trip.
      built.files[0].tracks[0].endTime = parseMsf('03:00:00');

      final reparsed = parseCueSheet(toCueString(built))!;
      expect(reparsed, equals(built));
      expect(reparsed.hashCode, built.hashCode);
    });

    test('Set<CueSheet> deduplicates structurally equal sheets', () {
      final set = <CueSheet>{
        parseCueSheet(_sampleCue)!,
        parseCueSheet(_sampleCue)!,
        parseCueSheet(_sampleCue)!,
      };
      expect(set.length, 1);
    });
  });

  group('CueFile equality', () {
    test('differs when filename changes', () {
      final a = parseCueSheet(_sampleCue)!.files[0];
      final b = CueFile(
        filename: 'other.wav',
        fileType: a.fileType,
        tracks: a.tracks,
      );
      expect(a, isNot(equals(b)));
    });

    test('differs when file type changes', () {
      final a = parseCueSheet(_sampleCue)!.files[0];
      final b = CueFile(
        filename: a.filename,
        fileType: CueFileType.mp3,
        tracks: a.tracks,
      );
      expect(a, isNot(equals(b)));
    });

    test('differs when a contained track differs', () {
      final a = parseCueSheet(_sampleCue)!.files[0];
      final b = parseCueSheet(
              _sampleCue.replaceAll('TITLE "One"', 'TITLE "Changed"'))!
          .files[0];
      expect(a, isNot(equals(b)));
    });
  });

  group('CueTrack equality', () {
    late CueTrack base;
    setUp(() => base = parseCueSheet(_sampleCue)!.files[0].tracks[0]);

    test('differs when an index is added', () {
      final other = CueTrack(
        trackNumber: base.trackNumber,
        trackType: base.trackType,
        title: base.title,
        performer: base.performer,
        isrc: base.isrc,
        pregap: base.pregap,
        flags: base.flags,
        indices: {...base.indices, 2: parseMsf('00:10:00')!},
        remComments: base.remComments,
      );
      expect(base, isNot(equals(other)));
    });

    test('differs when a flag is added', () {
      final other = CueTrack(
        trackNumber: base.trackNumber,
        trackType: base.trackType,
        title: base.title,
        flags: {...base.flags, CueFlag.scms},
        indices: base.indices,
      );
      expect(base, isNot(equals(other)));
    });

    test('differs when a track REM field changes', () {
      final other = CueTrack(
        trackNumber: base.trackNumber,
        trackType: base.trackType,
        title: base.title,
        flags: base.flags,
        indices: base.indices,
        remComments: {'REPLAYGAIN_TRACK_GAIN': '-99 dB'},
      );
      expect(base, isNot(equals(other)));
    });

    test('endTime participates in equality', () {
      final a = parseCueSheet(_sampleCue)!.files[0].tracks[0];
      final b = parseCueSheet(_sampleCue)!.files[0].tracks[0];
      expect(a, equals(b));
      b.endTime = b.endTime! + const Duration(seconds: 1);
      expect(a, isNot(equals(b)));
    });
  });

  group('toString', () {
    test('CueSheet.toString mentions title and counts', () {
      final s = parseCueSheet(_sampleCue)!;
      final str = s.toString();
      expect(str, contains('Great Album'));
      expect(str, contains('1 files'));
      expect(str, contains('2 tracks'));
    });

    test('CueTrack.toString mentions track number and title', () {
      final t = parseCueSheet(_sampleCue)!.files[0].tracks[0];
      final str = t.toString();
      expect(str, contains('#1'));
      expect(str, contains('One'));
    });

    test('CueFile.toString mentions filename and track count', () {
      final f = parseCueSheet(_sampleCue)!.files[0];
      final str = f.toString();
      expect(str, contains('album.wav'));
      expect(str, contains('2 tracks'));
    });
  });
}
