import 'package:dart_cue/dart_cue.dart';
import 'package:test/test.dart';

const _sampleCue = '''
CATALOG 1234567890123
PERFORMER "The Artist"
TITLE "Great Album"
SONGWRITER "The Writer"
REM GENRE Rock
REM DATE 2024
FILE "album.wav" WAVE
  TRACK 01 AUDIO
    TITLE "First Song"
    PERFORMER "Solo Artist"
    ISRC ZZABC1234567
    FLAGS DCP PRE
    PREGAP 00:02:00
    INDEX 00 00:00:00
    INDEX 01 00:02:00
    POSTGAP 00:00:37
  TRACK 02 AUDIO
    TITLE "Second Song"
    INDEX 01 04:15:25
''';

void main() {
  group('toCueString', () {
    test('produces non-empty output', () {
      final sheet = parseCueSheet(_sampleCue)!;
      expect(toCueString(sheet), isNotEmpty);
    });

    test('contains CATALOG', () {
      final sheet = parseCueSheet(_sampleCue)!;
      expect(toCueString(sheet), contains('CATALOG 1234567890123'));
    });

    test('contains PERFORMER', () {
      final sheet = parseCueSheet(_sampleCue)!;
      expect(toCueString(sheet), contains('PERFORMER'));
    });

    test('contains FILE line', () {
      final sheet = parseCueSheet(_sampleCue)!;
      expect(toCueString(sheet), contains('FILE'));
    });

    test('contains TRACK lines', () {
      final sheet = parseCueSheet(_sampleCue)!;
      final out = toCueString(sheet);
      expect(out, contains('TRACK 01 AUDIO'));
      expect(out, contains('TRACK 02 AUDIO'));
    });

    test('contains INDEX entries', () {
      final sheet = parseCueSheet(_sampleCue)!;
      final out = toCueString(sheet);
      expect(out, contains('INDEX 00'));
      expect(out, contains('INDEX 01'));
    });

    test('contains ISRC', () {
      final sheet = parseCueSheet(_sampleCue)!;
      expect(toCueString(sheet), contains('ISRC ZZABC1234567'));
    });

    test('contains FLAGS', () {
      final sheet = parseCueSheet(_sampleCue)!;
      final out = toCueString(sheet);
      expect(out, contains('FLAGS'));
      expect(out, contains('DCP'));
      expect(out, contains('PRE'));
    });

    test('contains PREGAP', () {
      final sheet = parseCueSheet(_sampleCue)!;
      expect(toCueString(sheet), contains('PREGAP'));
    });

    test('contains POSTGAP', () {
      final sheet = parseCueSheet(_sampleCue)!;
      expect(toCueString(sheet), contains('POSTGAP'));
    });

    test('contains REM entries', () {
      final sheet = parseCueSheet(_sampleCue)!;
      final out = toCueString(sheet);
      expect(out, contains('REM GENRE'));
      expect(out, contains('REM DATE'));
    });
  });

  group('round-trip', () {
    test('re-parse produces equivalent CueSheet', () {
      final original = parseCueSheet(_sampleCue)!;
      final serialised = toCueString(original);
      final reparsed = parseCueSheet(serialised)!;

      expect(reparsed.title, original.title);
      expect(reparsed.performer, original.performer);
      expect(reparsed.songwriter, original.songwriter);
      expect(reparsed.catalog, original.catalog);
      expect(reparsed.files.length, original.files.length);
      expect(reparsed.files[0].tracks.length, original.files[0].tracks.length);

      final t1orig = original.files[0].tracks[0];
      final t1rep = reparsed.files[0].tracks[0];
      expect(t1rep.title, t1orig.title);
      expect(t1rep.performer, t1orig.performer);
      expect(t1rep.isrc, t1orig.isrc);
      expect(t1rep.flags, t1orig.flags);
      expect(t1rep.indices[1], t1orig.indices[1]);
    });

    test('re-parse genre from REM', () {
      final original = parseCueSheet(_sampleCue)!;
      final reparsed = parseCueSheet(toCueString(original))!;
      expect(reparsed.genre, original.genre);
    });

    test('AIFC file type round-trips', () {
      final cue =
          'FILE "a.aifc" AIFC\n  TRACK 01 AUDIO\n    INDEX 01 00:00:00\n';
      final original = parseCueSheet(cue)!;
      final reparsed = parseCueSheet(toCueString(original))!;
      expect(reparsed.files[0].fileType, CueFileType.aifc);
    });

    test('DATA track type and FLAGS DATA round-trip', () {
      final cue =
          'FILE "a.bin" BINARY\n  TRACK 01 DATA\n    FLAGS DATA\n    INDEX 01 00:00:00\n';
      final reparsed = parseCueSheet(toCueString(parseCueSheet(cue)!))!;
      expect(reparsed.files[0].tracks[0].trackType, CueTrackType.data);
      expect(reparsed.files[0].tracks[0].flags, contains(CueFlag.data));
    });

    test('hand-built CueSheet serialises and re-parses equivalently', () {
      final original = CueSheet(
        performer: 'Built Artist',
        title: 'Built Album',
        catalog: '1234567890123',
        remComments: {'GENRE': 'Jazz', 'DATE': '2025'},
        files: [
          CueFile(
            filename: 'built.wav',
            fileType: CueFileType.wave,
            tracks: [
              CueTrack(
                trackNumber: 1,
                trackType: CueTrackType.audio,
                title: 'First',
                isrc: 'USABC1234567',
                flags: {CueFlag.dcp, CueFlag.preEmphasis},
                indices: {0: Duration.zero, 1: parseMsf('00:02:00')!},
                remComments: {'REPLAYGAIN_TRACK_GAIN': '-5 dB'},
              ),
              CueTrack(
                trackNumber: 2,
                trackType: CueTrackType.audio,
                title: 'Second',
                indices: {1: parseMsf('03:30:00')!},
              ),
            ],
          ),
        ],
      );
      final reparsed = parseCueSheet(toCueString(original))!;
      expect(reparsed.title, 'Built Album');
      expect(reparsed.performer, 'Built Artist');
      expect(reparsed.catalog, '1234567890123');
      expect(reparsed.genre, 'Jazz');
      expect(reparsed.files[0].tracks.length, 2);
      expect(reparsed.files[0].tracks[0].title, 'First');
      expect(reparsed.files[0].tracks[0].isrc, 'USABC1234567');
      expect(reparsed.files[0].tracks[0].flags,
          containsAll([CueFlag.dcp, CueFlag.preEmphasis]));
      expect(reparsed.files[0].tracks[0].indices[0], Duration.zero);
      expect(reparsed.files[0].tracks[0].remComments['REPLAYGAIN_TRACK_GAIN'],
          '-5 dB');
      expect(reparsed.files[0].tracks[1].title, 'Second');
    });

    test('track-level REM round-trip, separate from album REM', () {
      const cue = '''
REM GENRE Rock
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    TITLE "One"
    REM REPLAYGAIN_TRACK_GAIN -6.12 dB
    INDEX 01 00:00:00
''';
      final original = parseCueSheet(cue)!;
      final serialised = toCueString(original);
      final reparsed = parseCueSheet(serialised)!;
      expect(reparsed.remComments['GENRE'], 'Rock');
      expect(reparsed.files[0].tracks[0].remComments['REPLAYGAIN_TRACK_GAIN'],
          '-6.12 dB');
      expect(
          reparsed.remComments.containsKey('REPLAYGAIN_TRACK_GAIN'), isFalse);
    });
  });
}
