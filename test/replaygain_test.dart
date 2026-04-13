/// Tests for the ReplayGain convenience getters on CueSheet and CueTrack.
library;

import 'package:dart_cue/dart_cue.dart';
import 'package:test/test.dart';

CueSheet _parse(String album, {String track = ''}) {
  final cue = '''
$album
FILE "a.wav" WAVE
  TRACK 01 AUDIO
$track
    INDEX 01 00:00:00
''';
  return parseCueSheet(cue)!;
}

void main() {
  group('CueSheet — album ReplayGain', () {
    test('parses REPLAYGAIN_ALBUM_GAIN with " dB" suffix', () {
      final sheet = _parse('REM REPLAYGAIN_ALBUM_GAIN -6.12 dB');
      expect(sheet.replayGainAlbumGain, -6.12);
    });

    test('parses REPLAYGAIN_ALBUM_PEAK', () {
      final sheet = _parse('REM REPLAYGAIN_ALBUM_PEAK 0.987654');
      expect(sheet.replayGainAlbumPeak, closeTo(0.987654, 1e-9));
    });

    test('case-insensitive dB suffix variations', () {
      expect(_parse('REM REPLAYGAIN_ALBUM_GAIN -5 dB').replayGainAlbumGain, -5);
      expect(_parse('REM REPLAYGAIN_ALBUM_GAIN -5 DB').replayGainAlbumGain, -5);
      expect(_parse('REM REPLAYGAIN_ALBUM_GAIN -5dB').replayGainAlbumGain, -5);
      expect(_parse('REM REPLAYGAIN_ALBUM_GAIN +3.5 dB').replayGainAlbumGain,
          3.5);
    });

    test('missing REM → null', () {
      final sheet = _parse('');
      expect(sheet.replayGainAlbumGain, isNull);
      expect(sheet.replayGainAlbumPeak, isNull);
    });

    test('unparseable value → null, does not throw', () {
      final sheet = _parse('REM REPLAYGAIN_ALBUM_GAIN garbage dB');
      expect(sheet.replayGainAlbumGain, isNull);
    });

    test('empty value after stripping dB → null', () {
      final sheet = _parse('REM REPLAYGAIN_ALBUM_GAIN dB');
      expect(sheet.replayGainAlbumGain, isNull);
    });
  });

  group('CueTrack — track ReplayGain', () {
    test('parses REPLAYGAIN_TRACK_GAIN and PEAK', () {
      final sheet = _parse('', track: '    REM REPLAYGAIN_TRACK_GAIN -5.43 dB\n'
          '    REM REPLAYGAIN_TRACK_PEAK 0.976543');
      final track = sheet.files[0].tracks[0];
      expect(track.replayGainTrackGain, -5.43);
      expect(track.replayGainTrackPeak, closeTo(0.976543, 1e-9));
    });

    test('track getters read from the track, not the album', () {
      const cue = '''
REM REPLAYGAIN_ALBUM_GAIN -6.12 dB
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    REM REPLAYGAIN_TRACK_GAIN -5.43 dB
    INDEX 01 00:00:00
  TRACK 02 AUDIO
    INDEX 01 03:00:00
''';
      final sheet = parseCueSheet(cue)!;
      expect(sheet.replayGainAlbumGain, -6.12);
      expect(sheet.files[0].tracks[0].replayGainTrackGain, -5.43);
      // Track 2 has no track-level REM; the getter does NOT fall through
      // to the album value.
      expect(sheet.files[0].tracks[1].replayGainTrackGain, isNull);
    });

    test('missing → null', () {
      final sheet = _parse('');
      final track = sheet.files[0].tracks[0];
      expect(track.replayGainTrackGain, isNull);
      expect(track.replayGainTrackPeak, isNull);
    });

    test('unparseable track value → null', () {
      final sheet =
          _parse('', track: '    REM REPLAYGAIN_TRACK_GAIN not a number dB');
      expect(sheet.files[0].tracks[0].replayGainTrackGain, isNull);
    });
  });
}
