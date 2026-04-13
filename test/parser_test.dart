import 'package:dart_cue/dart_cue.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Sample CUE sheets used by multiple tests
// ---------------------------------------------------------------------------

const _minimalCue = '''
FILE "album.wav" WAVE
  TRACK 01 AUDIO
    TITLE "Track One"
    INDEX 01 00:00:00
''';

const _fullAlbumCue = '''
CATALOG 1234567890123
PERFORMER "The Artist"
TITLE "Great Album"
SONGWRITER "The Writer"
REM GENRE Rock
REM DATE 2024
REM DISCNUMBER 1
REM DISCID AB012345
REM COMMENT "Ripped with EAC"
FILE "great_album.wav" WAVE
  TRACK 01 AUDIO
    TITLE "First Song"
    PERFORMER "Solo Artist"
    SONGWRITER "Solo Writer"
    ISRC ZZABC1234567
    FLAGS DCP PRE
    PREGAP 00:02:00
    INDEX 00 00:00:00
    INDEX 01 00:02:00
    POSTGAP 00:00:37
  TRACK 02 AUDIO
    TITLE "Second Song"
    INDEX 01 04:15:25
  TRACK 03 AUDIO
    TITLE "Third Song"
    INDEX 01 08:00:00
''';

const _multiFileCue = '''
PERFORMER "Multi-File Artist"
TITLE "Multi-File Album"
FILE "disc1.wav" WAVE
  TRACK 01 AUDIO
    TITLE "Track 1"
    INDEX 01 00:00:00
  TRACK 02 AUDIO
    TITLE "Track 2"
    INDEX 01 03:10:00
FILE "disc2.aiff" AIFF
  TRACK 03 AUDIO
    TITLE "Track 3"
    INDEX 01 00:00:00
''';

const _eacStyleCue = '''
PERFORMER "Eac Artist"
TITLE "Eac Album"
FILE "eac album.wav" WAVE
  TRACK 01 AUDIO
    TITLE "Eac Track"
    PERFORMER "Eac Artist"
    INDEX 01 00:00:00
  TRACK 02 AUDIO
    TITLE "Second Track"
    INDEX 01 05:30:12
''';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('parseCueSheet — empty / null input', () {
    test('empty string → null', () {
      expect(parseCueSheet(''), isNull);
    });

    test('whitespace only → null', () {
      expect(parseCueSheet('   \n  \t  '), isNull);
    });
  });

  group('parseCueSheet — album metadata', () {
    late CueSheet sheet;
    setUp(() => sheet = parseCueSheet(_fullAlbumCue)!);

    test('catalog', () => expect(sheet.catalog, '1234567890123'));
    test('performer', () => expect(sheet.performer, 'The Artist'));
    test('title', () => expect(sheet.title, 'Great Album'));
    test('songwriter', () => expect(sheet.songwriter, 'The Writer'));
    test('genre convenience getter', () => expect(sheet.genre, 'Rock'));
    test('date convenience getter', () => expect(sheet.date, '2024'));
    test('discNumber convenience getter', () => expect(sheet.discNumber, 1));
    test('discId convenience getter', () => expect(sheet.discId, 'AB012345'));
    test('custom REM field', () => expect(sheet.remComments['COMMENT'], 'Ripped with EAC'));
  });

  group('parseCueSheet — track parsing', () {
    late CueSheet sheet;
    setUp(() => sheet = parseCueSheet(_fullAlbumCue)!);

    test('one file entry', () => expect(sheet.files.length, 1));
    test('three tracks', () => expect(sheet.files[0].tracks.length, 3));

    test('track 01 number', () => expect(sheet.files[0].tracks[0].trackNumber, 1));
    test('track 01 title', () => expect(sheet.files[0].tracks[0].title, 'First Song'));
    test('track 01 performer', () => expect(sheet.files[0].tracks[0].performer, 'Solo Artist'));
    test('track 01 songwriter', () => expect(sheet.files[0].tracks[0].songwriter, 'Solo Writer'));
    test('track 01 isrc', () => expect(sheet.files[0].tracks[0].isrc, 'ZZABC1234567'));
    test('track 01 flags', () {
      expect(sheet.files[0].tracks[0].flags, containsAll([CueFlag.dcp, CueFlag.preEmphasis]));
    });
    test('track 01 pregap', () {
      expect(sheet.files[0].tracks[0].pregap, parseMsf('00:02:00'));
    });
    test('track 01 postgap', () {
      expect(sheet.files[0].tracks[0].postgap, parseMsf('00:00:37'));
    });
  });

  group('parseCueSheet — INDEX handling', () {
    late CueTrack track1;
    setUp(() {
      final sheet = parseCueSheet(_fullAlbumCue)!;
      track1 = sheet.files[0].tracks[0];
    });

    test('INDEX 00 parsed', () => expect(track1.indices.containsKey(0), isTrue));
    test('INDEX 01 parsed', () => expect(track1.indices.containsKey(1), isTrue));
    test('INDEX 01 value', () => expect(track1.startTime, parseMsf('00:02:00')));
  });

  group('parseCueSheet — time derivation', () {
    late CueSheet sheet;
    setUp(() => sheet = parseCueSheet(_fullAlbumCue)!);

    test('track 1 endTime == track 2 startTime', () {
      final tracks = sheet.files[0].tracks;
      expect(tracks[0].endTime, tracks[1].startTime);
    });

    test('last track endTime is null', () {
      final tracks = sheet.files[0].tracks;
      expect(tracks.last.endTime, isNull);
    });

    test('track 1 duration is non-null', () {
      expect(sheet.files[0].tracks[0].duration, isNotNull);
    });
  });

  group('parseCueSheet — file type detection', () {
    test('WAVE', () {
      final sheet = parseCueSheet(_minimalCue)!;
      expect(sheet.files[0].fileType, CueFileType.wave);
    });

    test('AIFF from multi-file CUE', () {
      final sheet = parseCueSheet(_multiFileCue)!;
      expect(sheet.files[1].fileType, CueFileType.aiff);
    });

    test('MP3', () {
      final cue = 'FILE "a.mp3" MP3\n  TRACK 01 AUDIO\n    INDEX 01 00:00:00\n';
      expect(parseCueSheet(cue)!.files[0].fileType, CueFileType.mp3);
    });

    test('BINARY', () {
      final cue = 'FILE "a.bin" BINARY\n  TRACK 01 MODE1/2352\n    INDEX 01 00:00:00\n';
      expect(parseCueSheet(cue)!.files[0].fileType, CueFileType.binary);
    });
  });

  group('parseCueSheet — track type detection', () {
    test('AUDIO', () {
      final sheet = parseCueSheet(_minimalCue)!;
      expect(sheet.files[0].tracks[0].trackType, CueTrackType.audio);
    });

    test('MODE1/2352', () {
      final cue = 'FILE "a.bin" BINARY\n  TRACK 01 MODE1/2352\n    INDEX 01 00:00:00\n';
      expect(parseCueSheet(cue)!.files[0].tracks[0].trackType, CueTrackType.mode1_2352);
    });

    test('CDG', () {
      final cue = 'FILE "a.bin" BINARY\n  TRACK 01 CDG\n    INDEX 01 00:00:00\n';
      expect(parseCueSheet(cue)!.files[0].tracks[0].trackType, CueTrackType.cdg);
    });
  });

  group('parseCueSheet — multiple FILE entries', () {
    late CueSheet sheet;
    setUp(() => sheet = parseCueSheet(_multiFileCue)!);

    test('two file entries', () => expect(sheet.files.length, 2));
    test('file 1 has 2 tracks', () => expect(sheet.files[0].tracks.length, 2));
    test('file 2 has 1 track', () => expect(sheet.files[1].tracks.length, 1));
    test('file 1 filename', () => expect(sheet.files[0].filename, 'disc1.wav'));
    test('file 2 filename', () => expect(sheet.files[1].filename, 'disc2.aiff'));
    test('file 2 track title', () => expect(sheet.files[1].tracks[0].title, 'Track 3'));
  });

  group('parseCueSheet — quoted filenames with spaces', () {
    test('filename with space is unquoted', () {
      final sheet = parseCueSheet(_eacStyleCue)!;
      expect(sheet.files[0].filename, 'eac album.wav');
    });
  });

  group('parseCueSheet — REM comments', () {
    test('GENRE stored uppercased key', () {
      final sheet = parseCueSheet(_fullAlbumCue)!;
      expect(sheet.remComments.containsKey('GENRE'), isTrue);
    });

    test('custom REM field', () {
      final cue = 'REM CUSTOMKEY somevalue\nFILE "a.wav" WAVE\n  TRACK 01 AUDIO\n    INDEX 01 00:00:00\n';
      final sheet = parseCueSheet(cue)!;
      expect(sheet.remComments['CUSTOMKEY'], 'somevalue');
    });
  });

  group('parseCueSheet — Windows CRLF line endings', () {
    test('parsed correctly', () {
      final crlf = _minimalCue.replaceAll('\n', '\r\n');
      final sheet = parseCueSheet(crlf);
      expect(sheet, isNotNull);
      expect(sheet!.files[0].tracks[0].title, 'Track One');
    });
  });

  group('parseCueSheet — case-insensitive commands', () {
    test('mixed case TRACK/title/performer', () {
      const cue = '''
file "a.wav" wave
  track 01 audio
    title "Case Test"
    performer "Artist"
    index 01 00:00:00
''';
      final sheet = parseCueSheet(cue);
      expect(sheet, isNotNull);
      expect(sheet!.files[0].tracks[0].title, 'Case Test');
      expect(sheet.files[0].tracks[0].performer, 'Artist');
    });
  });

  group('parseCueSheet — spec coverage additions', () {
    test('AIFC file type', () {
      final cue = 'FILE "a.aifc" AIFC\n  TRACK 01 AUDIO\n    INDEX 01 00:00:00\n';
      expect(parseCueSheet(cue)!.files[0].fileType, CueFileType.aifc);
    });

    test('DATA track type', () {
      final cue = 'FILE "a.bin" BINARY\n  TRACK 01 DATA\n    INDEX 01 00:00:00\n';
      expect(parseCueSheet(cue)!.files[0].tracks[0].trackType, CueTrackType.data);
    });

    test('FLAGS DATA', () {
      final cue = 'FILE "a.wav" WAVE\n  TRACK 01 AUDIO\n    FLAGS DATA\n    INDEX 01 00:00:00\n';
      expect(parseCueSheet(cue)!.files[0].tracks[0].flags, contains(CueFlag.data));
    });

    test('track-level REM stored on track, not album', () {
      const cue = '''
REM GENRE Rock
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    TITLE "One"
    REM REPLAYGAIN_TRACK_GAIN -6.12 dB
    INDEX 01 00:00:00
  TRACK 02 AUDIO
    TITLE "Two"
    REM REPLAYGAIN_TRACK_GAIN -5.43 dB
    INDEX 01 03:00:00
''';
      final sheet = parseCueSheet(cue)!;
      final t1 = sheet.files[0].tracks[0];
      final t2 = sheet.files[0].tracks[1];
      expect(sheet.remComments['GENRE'], 'Rock');
      expect(sheet.remComments.containsKey('REPLAYGAIN_TRACK_GAIN'), isFalse);
      expect(t1.remComments['REPLAYGAIN_TRACK_GAIN'], '-6.12 dB');
      expect(t2.remComments['REPLAYGAIN_TRACK_GAIN'], '-5.43 dB');
    });
  });

  group('parseCueSheet — convenience getters', () {
    test('date falls back from DATE to YEAR when DATE absent', () {
      const cue = '''
REM YEAR 1999
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    INDEX 01 00:00:00
''';
      expect(parseCueSheet(cue)!.date, '1999');
    });

    test('DATE takes precedence over YEAR when both present', () {
      const cue = '''
REM YEAR 1999
REM DATE 2024
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    INDEX 01 00:00:00
''';
      expect(parseCueSheet(cue)!.date, '2024');
    });

    test('non-numeric DISCNUMBER returns null', () {
      const cue = '''
REM DISCNUMBER onehundred
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    INDEX 01 00:00:00
''';
      expect(parseCueSheet(cue)!.discNumber, isNull);
    });

    test('valid DISCNUMBER parses to int', () {
      const cue = '''
REM DISCNUMBER 2
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    INDEX 01 00:00:00
''';
      expect(parseCueSheet(cue)!.discNumber, 2);
    });

    test('missing REM fields → null getters', () {
      const cue = 'FILE "a.wav" WAVE\n  TRACK 01 AUDIO\n    INDEX 01 00:00:00\n';
      final sheet = parseCueSheet(cue)!;
      expect(sheet.genre, isNull);
      expect(sheet.date, isNull);
      expect(sheet.discId, isNull);
      expect(sheet.discNumber, isNull);
    });
  });

  group('parseCueSheet — error tolerance', () {
    test('missing PERFORMER → null, no crash', () {
      final sheet = parseCueSheet(_minimalCue)!;
      expect(sheet.performer, isNull);
    });

    test('track without INDEX 01 → startTime is null', () {
      const cue = 'FILE "a.wav" WAVE\n  TRACK 01 AUDIO\n    TITLE "No Index"\n';
      final sheet = parseCueSheet(cue)!;
      expect(sheet.files[0].tracks[0].startTime, isNull);
    });

    test('unrecognised commands ignored', () {
      const cue = '''
UNKNOWNCMD foo bar
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    INDEX 01 00:00:00
''';
      expect(() => parseCueSheet(cue), returnsNormally);
    });
  });
}
