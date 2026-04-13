/// Tests for the `cueinfo` CLI: pure validation logic plus end-to-end smoke
/// tests that actually run `bin/cueinfo.dart` as a subprocess.
library;

import 'dart:io';

import 'package:dart_cue/dart_cue.dart';
import 'package:test/test.dart';

// `validateCueSheet` now lives in the library; alias it so the existing
// tests keep reading like they did when it was defined in the CLI.
List<String> validateSheet(CueSheet sheet) =>
    validateCueSheet(sheet).map((i) => i.message).toList();

const _goodCue = '''
CATALOG 1234567890123
PERFORMER "The Artist"
TITLE "Great Album"
FILE "album.wav" WAVE
  TRACK 01 AUDIO
    TITLE "One"
    ISRC USABC1234567
    INDEX 01 00:00:00
  TRACK 02 AUDIO
    TITLE "Two"
    INDEX 01 03:00:00
''';

void main() {
  group('validateSheet', () {
    test('clean sheet → no issues', () {
      final sheet = parseCueSheet(_goodCue)!;
      expect(validateSheet(sheet), isEmpty);
    });

    test('missing INDEX 01 flagged', () {
      const cue = '''
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    TITLE "No Index"
''';
      final issues = validateSheet(parseCueSheet(cue)!);
      expect(issues.any((s) => s.contains('missing INDEX 01')), isTrue);
    });

    test('non-monotonic track numbers flagged', () {
      const cue = '''
FILE "a.wav" WAVE
  TRACK 02 AUDIO
    INDEX 01 00:00:00
  TRACK 01 AUDIO
    INDEX 01 03:00:00
''';
      final issues = validateSheet(parseCueSheet(cue)!);
      expect(issues.any((s) => s.contains('monotonically')), isTrue);
    });

    test('bad CATALOG length flagged', () {
      const cue = '''
CATALOG 123
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    INDEX 01 00:00:00
''';
      final issues = validateSheet(parseCueSheet(cue)!);
      expect(issues.any((s) => s.contains('CATALOG')), isTrue);
    });

    test('bad ISRC flagged', () {
      const cue = '''
FILE "a.wav" WAVE
  TRACK 01 AUDIO
    ISRC NOTANISRC
    INDEX 01 00:00:00
''';
      final issues = validateSheet(parseCueSheet(cue)!);
      expect(issues.any((s) => s.contains('ISRC')), isTrue);
    });

    test('out-of-range track number flagged', () {
      final sheet = CueSheet(files: [
        CueFile(filename: 'a.wav', fileType: CueFileType.wave, tracks: [
          CueTrack(
            trackNumber: 100,
            trackType: CueTrackType.audio,
            indices: {1: Duration.zero},
          ),
        ]),
      ]);
      final issues = validateSheet(sheet);
      expect(issues.any((s) => s.contains('out of range')), isTrue);
    });
  });

  group('cueinfo CLI (end-to-end)', () {
    late Directory tmpDir;
    late String goodPath;
    late String badPath;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('cueinfo_cli_');
      goodPath = '${tmpDir.path}/good.cue';
      await File(goodPath).writeAsString(_goodCue);
      badPath = '${tmpDir.path}/bad.cue';
      await File(badPath).writeAsString(
          'FILE "a.wav" WAVE\n  TRACK 01 AUDIO\n    TITLE "No Index"\n');
    });

    tearDown(() async => tmpDir.delete(recursive: true));

    Future<ProcessResult> run(List<String> args) =>
        Process.run('dart', ['run', 'bin/cueinfo.dart', ...args]);

    test('no args prints usage and exits 2', () async {
      final r = await run([]);
      expect(r.exitCode, 2);
      expect(r.stdout, contains('Usage: cueinfo'));
    });

    test('--help exits 0', () async {
      final r = await run(['--help']);
      expect(r.exitCode, 0);
    });

    test('info --format text prints Title', () async {
      final r = await run(['info', goodPath, '--format', 'text']);
      expect(r.exitCode, 0);
      expect(r.stdout, contains('Title'));
      expect(r.stdout, contains('Great Album'));
    });

    test('info --format json returns parseable JSON', () async {
      final r = await run(['info', goodPath, '--format', 'json']);
      expect(r.exitCode, 0);
      expect(r.stdout, startsWith('{'));
      expect(r.stdout, contains('"title"'));
    });

    test('back-compat: plain file path invokes info', () async {
      final r = await run([goodPath, '--format', 'text']);
      expect(r.exitCode, 0);
      expect(r.stdout, contains('Great Album'));
    });

    test('validate on good file exits 0', () async {
      final r = await run(['validate', goodPath]);
      expect(r.exitCode, 0);
      expect(r.stdout, contains('OK'));
    });

    test('validate on bad file exits 1 and reports issue', () async {
      final r = await run(['validate', badPath]);
      expect(r.exitCode, 1);
      expect(r.stderr, contains('INDEX 01'));
    });

    test('reformat emits round-trippable CUE', () async {
      final r = await run(['reformat', goodPath]);
      expect(r.exitCode, 0);
      final reparsed = parseCueSheet(r.stdout as String)!;
      expect(reparsed.title, 'Great Album');
      expect(reparsed.files[0].tracks.length, 2);
    });

    test('tracks prints one line per track', () async {
      final r = await run(['tracks', goodPath]);
      expect(r.exitCode, 0);
      final lines = (r.stdout as String)
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      expect(lines.length, 2);
      expect(lines[0], contains('One'));
      expect(lines[1], contains('Two'));
    });
  });
}
