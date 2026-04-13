/// Tests for `copyWith` on CueSheet, CueFile and CueTrack.
library;

import 'package:dart_cue/dart_cue.dart';
import 'package:test/test.dart';

const _cue = '''
CATALOG 1234567890123
PERFORMER "Artist"
TITLE "Album"
REM GENRE Rock
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    TITLE "One"
    FLAGS DCP
    INDEX 01 00:00:00
  TRACK 02 AUDIO
    TITLE "Two"
    INDEX 01 03:00:00
''';

void main() {
  group('CueTrack.copyWith', () {
    late CueTrack base;
    setUp(() => base = parseCueSheet(_cue)!.files[0].tracks[0]);

    test('no args returns an equal but distinct instance', () {
      final c = base.copyWith();
      expect(c, equals(base));
      expect(identical(c, base), isFalse);
    });

    test('replacing title differs from original', () {
      final c = base.copyWith(title: 'Changed');
      expect(c.title, 'Changed');
      expect(c, isNot(equals(base)));
      expect(c.trackNumber, base.trackNumber);
      expect(c.flags, base.flags);
    });

    test('replacing indices differs from original', () {
      final c = base.copyWith(indices: {1: parseMsf('00:05:00')!});
      expect(c.indices[1], parseMsf('00:05:00'));
      expect(c, isNot(equals(base)));
    });

    test('endTime carries through', () {
      base.endTime = parseMsf('03:00:00');
      final c = base.copyWith(title: 'Changed');
      expect(c.endTime, parseMsf('03:00:00'));
    });

    test('endTime can be replaced via copyWith', () {
      final c = base.copyWith(endTime: parseMsf('05:00:00'));
      expect(c.endTime, parseMsf('05:00:00'));
    });
  });

  group('CueFile.copyWith', () {
    late CueFile base;
    setUp(() => base = parseCueSheet(_cue)!.files[0]);

    test('no args equal', () {
      expect(base.copyWith(), equals(base));
    });

    test('replacing filename', () {
      final c = base.copyWith(filename: 'other.wav');
      expect(c.filename, 'other.wav');
      expect(c, isNot(equals(base)));
    });

    test('replacing tracks', () {
      final c = base.copyWith(tracks: []);
      expect(c.tracks, isEmpty);
    });
  });

  group('CueSheet.copyWith', () {
    late CueSheet base;
    setUp(() => base = parseCueSheet(_cue)!);

    test('no args equal', () {
      expect(base.copyWith(), equals(base));
    });

    test('replacing title leaves everything else intact', () {
      final c = base.copyWith(title: 'New Title');
      expect(c.title, 'New Title');
      expect(c.performer, base.performer);
      expect(c.catalog, base.catalog);
      expect(c.files, base.files);
      expect(c.remComments, base.remComments);
      expect(c, isNot(equals(base)));
    });

    test('replacing remComments updates convenience getters', () {
      final c = base.copyWith(remComments: {'GENRE': 'Jazz'});
      expect(c.genre, 'Jazz');
    });

    test('replacing files', () {
      final c = base.copyWith(files: []);
      expect(c.files, isEmpty);
      expect(c.title, base.title);
    });
  });
}
