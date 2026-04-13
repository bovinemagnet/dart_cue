/// cueinfo — command-line inspector, validator and reformatter for CUE
/// sheets, built on the `dart_cue` library.
///
/// Subcommands:
///
/// - `info      <file> [--format text|json]`  (default)
/// - `validate  <file>`  exit 0 = clean, 1 = problems
/// - `reformat  <file>`  parse → canonical CUE on stdout
/// - `tracks    <file>`  one line per track
library;

import 'dart:convert';
import 'dart:io';

import 'package:dart_cue/dart_cue.dart';

const _usage = '''
Usage: cueinfo <command> <file.cue> [options]

Commands:
  info       Print album and track metadata (default).
  validate   Parse and report structural problems. Exits non-zero on issues.
  reformat   Emit a canonical CUE representation (round-trip through the parser).
  tracks     One-line-per-track listing with durations.

Options for `info`:
  --format text|json    Output format (default: json)

  -h, --help            Show this help.
''';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first == '-h' || args.first == '--help') {
    stdout.writeln(_usage);
    exit(args.isEmpty ? 2 : 0);
  }

  final command = args.first;
  final rest = args.sublist(1);

  switch (command) {
    case 'info':
      await _cmdInfo(rest);
    case 'validate':
      await _cmdValidate(rest);
    case 'reformat':
      await _cmdReformat(rest);
    case 'tracks':
      await _cmdTracks(rest);
    default:
      // Back-compat: `cueinfo foo.cue [--format …]` still works.
      if (command.startsWith('-') == false) {
        await _cmdInfo(args);
        return;
      }
      stderr.writeln('Unknown command: $command\n');
      stderr.writeln(_usage);
      exit(2);
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

Future<CueSheet> _loadOrDie(String path) async {
  final sheet = await parseCueFile(path);
  if (sheet == null) {
    stderr.writeln('Error: could not parse "$path".');
    exit(1);
  }
  return sheet;
}

({String path, Map<String, String> opts}) _parseFileAndOpts(
    List<String> args, Set<String> knownFlags) {
  String? path;
  final opts = <String, String>{};
  for (int i = 0; i < args.length; i++) {
    final a = args[i];
    if (knownFlags.contains(a) && i + 1 < args.length) {
      opts[a] = args[++i];
    } else if (a.startsWith('--')) {
      stderr.writeln('Unknown option: $a');
      exit(2);
    } else {
      if (path != null) {
        stderr.writeln('Error: multiple file paths provided.');
        exit(2);
      }
      path = a;
    }
  }
  if (path == null) {
    stderr.writeln('Error: no file path provided.');
    exit(2);
  }
  return (path: path, opts: opts);
}

// ---------------------------------------------------------------------------
// info
// ---------------------------------------------------------------------------

Future<void> _cmdInfo(List<String> args) async {
  final parsed = _parseFileAndOpts(args, {'--format'});
  final sheet = await _loadOrDie(parsed.path);
  final format = (parsed.opts['--format'] ?? 'json').toLowerCase();
  if (format == 'text') {
    _printText(sheet);
  } else if (format == 'json') {
    _printJson(sheet);
  } else {
    stderr.writeln('Error: --format must be text or json.');
    exit(2);
  }
}

void _printJson(CueSheet sheet) {
  final map = <String, dynamic>{
    if (sheet.title != null) 'title': sheet.title,
    if (sheet.performer != null) 'performer': sheet.performer,
    if (sheet.songwriter != null) 'songwriter': sheet.songwriter,
    if (sheet.catalog != null) 'catalog': sheet.catalog,
    if (sheet.cdTextFile != null) 'cdTextFile': sheet.cdTextFile,
    if (sheet.remComments.isNotEmpty) 'remComments': sheet.remComments,
    'files': [
      for (final file in sheet.files)
        {
          'filename': file.filename,
          'fileType': file.fileType.toLabel(),
          'tracks': [
            for (final t in file.tracks)
              {
                'trackNumber': t.trackNumber,
                'trackType': t.trackType.toLabel(),
                if (t.title != null) 'title': t.title,
                if (t.performer != null) 'performer': t.performer,
                if (t.songwriter != null) 'songwriter': t.songwriter,
                if (t.isrc != null) 'isrc': t.isrc,
                if (t.pregap != null) 'pregap': formatMsf(t.pregap!),
                if (t.postgap != null) 'postgap': formatMsf(t.postgap!),
                if (t.flags.isNotEmpty)
                  'flags': t.flags.map((f) => f.toToken()).toList(),
                if (t.remComments.isNotEmpty) 'remComments': t.remComments,
                'indices': {
                  for (final e in t.indices.entries)
                    e.key.toString(): formatMsf(e.value),
                },
                if (t.startTime != null) 'startTime': formatMsf(t.startTime!),
                if (t.endTime != null) 'endTime': formatMsf(t.endTime!),
                if (t.duration != null) 'duration': formatMsf(t.duration!),
              },
          ],
        },
    ],
  };
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(map));
}

void _printText(CueSheet sheet) {
  if (sheet.title != null) print('Title     : ${sheet.title}');
  if (sheet.performer != null) print('Performer : ${sheet.performer}');
  if (sheet.songwriter != null) print('Songwriter: ${sheet.songwriter}');
  if (sheet.catalog != null) print('Catalog   : ${sheet.catalog}');
  if (sheet.genre != null) print('Genre     : ${sheet.genre}');
  if (sheet.date != null) print('Date      : ${sheet.date}');
  if (sheet.discNumber != null) print('Disc      : ${sheet.discNumber}');

  for (final file in sheet.files) {
    print('\nFILE "${file.filename}" ${file.fileType.toLabel()}');
    for (final t in file.tracks) {
      print('  TRACK ${t.trackNumber.toString().padLeft(2, '0')} '
          '${t.trackType.toLabel()}');
      if (t.title != null) print('    Title     : ${t.title}');
      if (t.performer != null) print('    Performer : ${t.performer}');
      if (t.songwriter != null) print('    Songwriter: ${t.songwriter}');
      if (t.isrc != null) print('    ISRC      : ${t.isrc}');
      for (final e in t.indices.entries) {
        print('    INDEX ${e.key.toString().padLeft(2, '0')} '
            '${formatMsf(e.value)}');
      }
      if (t.startTime != null) {
        print('    Start     : ${formatMsf(t.startTime!)}');
      }
      if (t.endTime != null) print('    End       : ${formatMsf(t.endTime!)}');
      if (t.duration != null) {
        print('    Duration  : ${formatMsf(t.duration!)}');
      }
    }
  }
}

// ---------------------------------------------------------------------------
// validate
// ---------------------------------------------------------------------------

Future<void> _cmdValidate(List<String> args) async {
  final parsed = _parseFileAndOpts(args, {});
  final sheet = await _loadOrDie(parsed.path);

  final issues = validateSheet(sheet);
  if (issues.isEmpty) {
    print('${parsed.path}: OK');
    exit(0);
  }
  for (final issue in issues) {
    stderr.writeln('${parsed.path}: $issue');
  }
  exit(1);
}

/// Structural validation. Returns a list of human-readable issue strings;
/// an empty list means the sheet looks well-formed. Exposed for testing.
List<String> validateSheet(CueSheet sheet) {
  final issues = <String>[];

  if (sheet.files.isEmpty) {
    issues.add('no FILE entries');
  }

  if (sheet.catalog != null && !RegExp(r'^\d{13}$').hasMatch(sheet.catalog!)) {
    issues.add('CATALOG "${sheet.catalog}" is not 13 digits');
  }

  int? previousTrackNumber;
  for (final file in sheet.files) {
    if (file.filename.isEmpty) {
      issues.add('FILE entry has empty filename');
    }
    if (file.tracks.isEmpty) {
      issues.add('FILE "${file.filename}" has no tracks');
    }
    for (final t in file.tracks) {
      final where = 'TRACK ${t.trackNumber.toString().padLeft(2, '0')}';
      if (t.trackNumber < 1 || t.trackNumber > 99) {
        issues.add('$where: track number out of range (1-99)');
      }
      if (previousTrackNumber != null && t.trackNumber <= previousTrackNumber) {
        issues.add('$where: track number does not increase monotonically');
      }
      previousTrackNumber = t.trackNumber;

      if (!t.indices.containsKey(1)) {
        issues.add('$where: missing INDEX 01');
      }
      if (t.isrc != null &&
          !RegExp(r'^[A-Z]{2}[A-Z0-9]{3}\d{7}$').hasMatch(t.isrc!)) {
        issues.add('$where: ISRC "${t.isrc}" is malformed');
      }
    }
  }
  return issues;
}

// ---------------------------------------------------------------------------
// reformat
// ---------------------------------------------------------------------------

Future<void> _cmdReformat(List<String> args) async {
  final parsed = _parseFileAndOpts(args, {});
  final sheet = await _loadOrDie(parsed.path);
  stdout.write(toCueString(sheet));
}

// ---------------------------------------------------------------------------
// tracks
// ---------------------------------------------------------------------------

Future<void> _cmdTracks(List<String> args) async {
  final parsed = _parseFileAndOpts(args, {});
  final sheet = await _loadOrDie(parsed.path);

  for (final file in sheet.files) {
    for (final t in file.tracks) {
      final num = t.trackNumber.toString().padLeft(2, '0');
      final dur = t.duration == null ? '  —  ' : formatMsf(t.duration!);
      final artist = t.performer ?? sheet.performer ?? '';
      final title = t.title ?? '';
      print('$num  $dur  ${artist.isEmpty ? '' : '$artist — '}$title');
    }
  }
}
