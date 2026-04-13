/// Immutability contract for parsed `CueSheet` objects.
///
/// After parsing, collections on the returned model are unmodifiable so
/// consumers can safely share them across isolates / cache layers without
/// defensive copies. These tests pin that contract down.
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
    expect(() => sheet.files.add(sheet.files.first),
        throwsUnsupportedError);
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
}
