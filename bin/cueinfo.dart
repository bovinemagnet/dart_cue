/// cueinfo — command-line tool for inspecting CUE sheets.
///
/// Usage:
///   dart run bin/cueinfo.dart <path/to/file.cue> [--format text|json]
library;

import 'dart:convert';
import 'dart:io';

import 'package:dart_cue/dart_cue.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: cueinfo <file.cue> [--format text|json]');
    exit(2);
  }

  String? formatArg;
  String? filePath;

  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--format' && i + 1 < args.length) {
      formatArg = args[i + 1];
      i++;
    } else {
      filePath = args[i];
    }
  }

  if (filePath == null) {
    stderr.writeln('Error: no file path provided.');
    exit(2);
  }

  final sheet = await parseCueFile(filePath);
  if (sheet == null) {
    stderr.writeln('Error: could not parse "$filePath".');
    exit(2);
  }

  final format = (formatArg ?? 'json').toLowerCase();
  if (format == 'text') {
    _printText(sheet);
  } else {
    _printJson(sheet);
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

  final encoder = JsonEncoder.withIndent('  ');
  print(encoder.convert(map));
}

void _printText(CueSheet sheet) {
  if (sheet.title != null) print('Title    : ${sheet.title}');
  if (sheet.performer != null) print('Performer: ${sheet.performer}');
  if (sheet.songwriter != null) print('Songwriter: ${sheet.songwriter}');
  if (sheet.catalog != null) print('Catalog  : ${sheet.catalog}');
  if (sheet.genre != null) print('Genre    : ${sheet.genre}');
  if (sheet.date != null) print('Date     : ${sheet.date}');
  if (sheet.discNumber != null) print('Disc     : ${sheet.discNumber}');

  for (final file in sheet.files) {
    print('\nFILE "${file.filename}" ${file.fileType.toLabel()}');
    for (final t in file.tracks) {
      print(
          '  TRACK ${t.trackNumber.toString().padLeft(2, '0')} ${t.trackType.toLabel()}');
      if (t.title != null) print('    Title    : ${t.title}');
      if (t.performer != null) print('    Performer: ${t.performer}');
      if (t.songwriter != null) print('    Songwriter: ${t.songwriter}');
      if (t.isrc != null) print('    ISRC     : ${t.isrc}');
      for (final e in t.indices.entries) {
        print(
            '    INDEX ${e.key.toString().padLeft(2, '0')} ${formatMsf(e.value)}');
      }
      if (t.startTime != null) print('    Start    : ${formatMsf(t.startTime!)}');
      if (t.endTime != null) print('    End      : ${formatMsf(t.endTime!)}');
      if (t.duration != null) print('    Duration : ${formatMsf(t.duration!)}');
    }
  }
}
