/// Tests for `parseCueSheetWithDiagnostics` and `validateCueSheet`.
library;

import 'package:dart_cue/dart_cue.dart';
import 'package:test/test.dart';

void main() {
  group('parseCueSheetWithDiagnostics — clean input', () {
    test('well-formed sheet produces no issues', () {
      const cue = '''
CATALOG 1234567890123
PERFORMER "OK"
TITLE "OK"
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    ISRC USABC1234567
    INDEX 01 00:00:00
  TRACK 02 AUDIO
    INDEX 01 03:00:00
''';
      final result = parseCueSheetWithDiagnostics(cue);
      expect(result.sheet, isNotNull);
      expect(result.issues, isEmpty);
      expect(result.hasIssues, isFalse);
    });

    test('empty input → null sheet, no issues', () {
      final result = parseCueSheetWithDiagnostics('');
      expect(result.sheet, isNull);
      expect(result.issues, isEmpty);
    });
  });

  group('parse-time diagnostics', () {
    test('unknown FILE type reported with line number', () {
      const cue = '''
FILE "a.xyz" XYZ
  TRACK 01 AUDIO
    INDEX 01 00:00:00
''';
      final issues = parseCueSheetWithDiagnostics(cue).issues;
      final unknown =
          issues.where((i) => i.message.contains('FILE type')).toList();
      expect(unknown.length, 1);
      expect(unknown.single.line, 1);
      expect(unknown.single.message, contains('XYZ'));
      expect(unknown.single.severity, CueIssueSeverity.warning);
    });

    test('unknown TRACK type reported', () {
      const cue = '''
FILE "a.wav" WAVE
  TRACK 01 WEIRD
    INDEX 01 00:00:00
''';
      final issues = parseCueSheetWithDiagnostics(cue).issues;
      expect(issues.any((i) => i.message.contains('TRACK type') && i.line == 2),
          isTrue);
    });

    test('unknown FLAGS token reported', () {
      const cue = '''
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    FLAGS DCP BOGUS
    INDEX 01 00:00:00
''';
      final issues = parseCueSheetWithDiagnostics(cue).issues;
      expect(issues.any((i) => i.message.contains('BOGUS')), isTrue);
    });

    test('malformed INDEX timestamp reported', () {
      const cue = '''
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    INDEX 01 99:99:99
''';
      final issues = parseCueSheetWithDiagnostics(cue).issues;
      final bad = issues.where((i) => i.message.contains('INDEX timestamp'));
      expect(bad, hasLength(1));
      expect(bad.single.line, 3);
    });

    test('malformed PREGAP timestamp reported', () {
      const cue = '''
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    PREGAP not:a:time
    INDEX 01 00:00:00
''';
      final issues = parseCueSheetWithDiagnostics(cue).issues;
      expect(issues.any((i) => i.message.contains('PREGAP timestamp')), isTrue);
    });

    test('INDEX outside TRACK reported', () {
      const cue = '''
INDEX 01 00:00:00
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    INDEX 01 00:00:00
''';
      final issues = parseCueSheetWithDiagnostics(cue).issues;
      expect(
          issues.any((i) =>
              i.message.contains('INDEX outside any TRACK') && i.line == 1),
          isTrue);
    });

    test('TRACK with non-numeric number reported', () {
      const cue = '''
FILE "a.wav" WAVE
  TRACK XX AUDIO
    INDEX 01 00:00:00
''';
      final issues = parseCueSheetWithDiagnostics(cue).issues;
      expect(
          issues.any((i) =>
              i.message.contains('track number must be numeric') &&
              i.line == 2),
          isTrue);
    });

    test('line numbers survive CRLF and blank lines', () {
      const cue = 'FILE "a.wav" WAVE\r\n'
          '\r\n'
          '  TRACK 01 AUDIO\r\n'
          '\r\n'
          '    FLAGS BOGUS\r\n'
          '    INDEX 01 00:00:00\r\n';
      final issues = parseCueSheetWithDiagnostics(cue).issues;
      final bogus = issues.firstWhere((i) => i.message.contains('BOGUS'));
      // After CRLF normalisation the BOGUS line is line 5 (1-based).
      expect(bogus.line, 5);
    });
  });

  group('validateCueSheet — post-parse', () {
    test('clean sheet → empty', () {
      final sheet = parseCueSheet('''
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    INDEX 01 00:00:00
''')!;
      expect(validateCueSheet(sheet), isEmpty);
    });

    test('missing INDEX 01 flagged', () {
      final sheet = parseCueSheet('''
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    TITLE "No Index"
''')!;
      final issues = validateCueSheet(sheet);
      expect(issues.any((i) => i.message.contains('missing INDEX 01')), isTrue);
    });

    test('non-monotonic track numbers flagged', () {
      final sheet = parseCueSheet('''
FILE "a.wav" WAVE
  TRACK 02 AUDIO
    INDEX 01 00:00:00
  TRACK 01 AUDIO
    INDEX 01 03:00:00
''')!;
      final issues = validateCueSheet(sheet);
      expect(issues.any((i) => i.message.contains('monotonically')), isTrue);
    });

    test('bad CATALOG flagged', () {
      final sheet = parseCueSheet('''
CATALOG 123
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    INDEX 01 00:00:00
''')!;
      expect(validateCueSheet(sheet).any((i) => i.message.contains('CATALOG')),
          isTrue);
    });

    test('bad ISRC flagged', () {
      final sheet = parseCueSheet('''
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    ISRC NOTANISRC
    INDEX 01 00:00:00
''')!;
      expect(validateCueSheet(sheet).any((i) => i.message.contains('ISRC')),
          isTrue);
    });

    test('out-of-range track number flagged (hand-built)', () {
      final sheet = CueSheet(files: [
        CueFile(filename: 'a.wav', fileType: CueFileType.wave, tracks: [
          CueTrack(
            trackNumber: 100,
            trackType: CueTrackType.audio,
            indices: {1: Duration.zero},
          ),
        ]),
      ]);
      expect(
          validateCueSheet(sheet)
              .any((i) => i.message.contains('out of range')),
          isTrue);
    });
  });

  group('CueIssue value semantics', () {
    test('equality and toString', () {
      const a = CueIssue(
          line: 3, severity: CueIssueSeverity.warning, message: 'boom');
      const b = CueIssue(
          line: 3, severity: CueIssueSeverity.warning, message: 'boom');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('line 3'));
      expect(a.toString(), contains('WARNING'));
      expect(a.toString(), contains('boom'));
    });
  });

  group('ParseResult', () {
    test('carries both sheet and issues together', () {
      final result = parseCueSheetWithDiagnostics('''
FILE "a.xyz" XYZ
  TRACK 01 AUDIO
    INDEX 01 00:00:00
''');
      expect(result.sheet, isNotNull);
      expect(result.sheet!.files.single.fileType, CueFileType.wave);
      expect(result.issues, isNotEmpty);
      expect(result.hasIssues, isTrue);
    });

    test('issues list is unmodifiable', () {
      final result = parseCueSheetWithDiagnostics('''
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    INDEX 01 00:00:00
''');
      expect(
          () => result.issues.add(
              const CueIssue(severity: CueIssueSeverity.warning, message: 'x')),
          throwsUnsupportedError);
    });
  });
}
