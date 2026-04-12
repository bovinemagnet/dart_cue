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
  });
}
