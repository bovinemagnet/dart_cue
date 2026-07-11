/// Immutability contract for `CueSheet` objects, parsed or hand-built.
///
/// Collections on the model are unmodifiable — constructors defensively
/// copy their collection arguments — so consumers can safely share sheets
/// across isolates / cache layers without defensive copies. These tests
/// pin that contract down.
library;

import 'package:dart_cue/dart_cue.dart';
import 'package:test/test.dart';

const _cue = '''
REM GENRE Rock
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    TITLE "One"
    FLAGS DCP
    REM REPLAYGAIN_TRACK_GAIN -6 dB
    INDEX 01 00:00:00
  TRACK 02 AUDIO
    TITLE "Two"
    INDEX 01 03:00:00
''';

void main() {
  late CueSheet sheet;
  setUp(() => sheet = parseCueSheet(_cue)!);

  test('sheet.files is unmodifiable', () {
    expect(() => sheet.files.add(sheet.files.first), throwsUnsupportedError);
    expect(() => sheet.files.clear(), throwsUnsupportedError);
  });

  test('sheet.remComments is unmodifiable', () {
    expect(() => sheet.remComments['NEW'] = 'x', throwsUnsupportedError);
    expect(() => sheet.remComments.remove('GENRE'), throwsUnsupportedError);
  });

  test('file.tracks is unmodifiable', () {
    final file = sheet.files.first;
    expect(() => file.tracks.removeAt(0), throwsUnsupportedError);
  });

  test('track.indices is unmodifiable', () {
    final t = sheet.files.first.tracks.first;
    expect(() => t.indices[99] = Duration.zero, throwsUnsupportedError);
  });

  test('track.flags is unmodifiable', () {
    final t = sheet.files.first.tracks.first;
    expect(() => t.flags.add(CueFlag.scms), throwsUnsupportedError);
  });

  test('track.remComments is unmodifiable', () {
    final t = sheet.files.first.tracks.first;
    expect(() => t.remComments['NEW'] = 'x', throwsUnsupportedError);
  });

  group('hand-built models', () {
    test('CueSheet default collections are unmodifiable', () {
      final s = CueSheet();
      expect(
          () => s.files.add(CueFile(filename: 'a', fileType: CueFileType.wave)),
          throwsUnsupportedError);
      expect(() => s.remComments['K'] = 'v', throwsUnsupportedError);
    });

    test('CueFile default tracks list is unmodifiable', () {
      final f = CueFile(filename: 'a', fileType: CueFileType.wave);
      expect(
          () => f.tracks
              .add(CueTrack(trackNumber: 1, trackType: CueTrackType.audio)),
          throwsUnsupportedError);
    });

    test('passed-in collections are defensively copied', () {
      final tracks = [
        CueTrack(trackNumber: 1, trackType: CueTrackType.audio),
      ];
      final f =
          CueFile(filename: 'a', fileType: CueFileType.wave, tracks: tracks);
      tracks.add(CueTrack(trackNumber: 2, trackType: CueTrackType.audio));
      expect(f.tracks, hasLength(1));
      expect(() => f.tracks.clear(), throwsUnsupportedError);
    });

    test('CueTrack passed-in collections are defensively copied', () {
      final indices = {1: Duration.zero};
      final flags = {CueFlag.dcp};
      final t = CueTrack(
        trackNumber: 1,
        trackType: CueTrackType.audio,
        indices: indices,
        flags: flags,
      );
      indices[2] = const Duration(minutes: 1);
      flags.add(CueFlag.scms);
      expect(t.indices, hasLength(1));
      expect(t.flags, hasLength(1));
      expect(() => t.indices[3] = Duration.zero, throwsUnsupportedError);
      expect(() => t.flags.add(CueFlag.preEmphasis), throwsUnsupportedError);
    });

    test('copyWith does not share mutable state with the source', () {
      final tracks = [
        CueTrack(trackNumber: 1, trackType: CueTrackType.audio),
      ];
      final f =
          CueFile(filename: 'a', fileType: CueFileType.wave, tracks: tracks);
      final copy = f.copyWith(filename: 'b');
      tracks.add(CueTrack(trackNumber: 2, trackType: CueTrackType.audio));
      expect(copy.tracks, hasLength(1));
      expect(() => copy.tracks.clear(), throwsUnsupportedError);
    });
  });
}
