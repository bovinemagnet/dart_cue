/// Example: parse a CUE sheet, inspect its metadata, and round-trip it
/// back to CUE-format text.
///
/// Run with:
///   dart run example/dart_cue_example.dart
library;

import 'package:dart_cue/dart_cue.dart';

const _sampleCue = '''
CATALOG 1234567890123
PERFORMER "The Artist"
TITLE "Great Album"
REM GENRE Rock
REM DATE 2024
FILE "great_album.wav" WAVE
  TRACK 01 AUDIO
    TITLE "First Song"
    PERFORMER "Solo Artist"
    ISRC ZZABC1234567
    FLAGS DCP PRE
    PREGAP 00:02:00
    INDEX 00 00:00:00
    INDEX 01 00:02:00
    REM REPLAYGAIN_TRACK_GAIN -6.12 dB
  TRACK 02 AUDIO
    TITLE "Second Song"
    INDEX 01 04:15:25
  TRACK 03 AUDIO
    TITLE "Third Song"
    INDEX 01 08:00:00
''';

void main() {
  final sheet = parseCueSheet(_sampleCue);
  if (sheet == null) {
    print('No CUE data.');
    return;
  }

  // Album metadata
  print('${sheet.performer} — ${sheet.title}');
  print('Catalog: ${sheet.catalog}');
  print('Genre:   ${sheet.genre}');
  print('Date:    ${sheet.date}');

  // Tracks with derived durations
  for (final file in sheet.files) {
    print('\nFILE ${file.filename} (${file.fileType.toLabel()})');
    for (final t in file.tracks) {
      final duration = t.duration == null ? '—' : formatMsf(t.duration!);
      print('  ${t.trackNumber.toString().padLeft(2, '0')} '
          '${t.title}  [$duration]');
      if (t.remComments.isNotEmpty) {
        print('       REM: ${t.remComments}');
      }
    }
  }

  // Lossless round-trip
  final roundTripped = toCueString(sheet);
  print('\n--- Round-tripped CUE ---\n$roundTripped');
}
