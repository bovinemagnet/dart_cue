/// CUE sheet serialiser — converts a [CueSheet] back to a CUE-format string.
library;

import 'models.dart';
import 'msf.dart';

/// Serialise [sheet] to a CUE-format string.
///
/// The output is suitable for writing back to a `.cue` file and can be
/// re-parsed with [parseCueSheet] to obtain an equivalent [CueSheet].
String toCueString(CueSheet sheet) {
  final buf = StringBuffer();

  void writeLine(String line) => buf.writeln(line);
  String q(String s) => s.contains(' ') ? '"$s"' : s;

  if (sheet.catalog != null) writeLine('CATALOG ${sheet.catalog}');
  if (sheet.cdTextFile != null) writeLine('CDTEXTFILE ${q(sheet.cdTextFile!)}');
  if (sheet.performer != null) writeLine('PERFORMER ${q(sheet.performer!)}');
  if (sheet.songwriter != null) writeLine('SONGWRITER ${q(sheet.songwriter!)}');
  if (sheet.title != null) writeLine('TITLE ${q(sheet.title!)}');

  for (final entry in sheet.remComments.entries) {
    writeLine('REM ${entry.key} ${entry.value}');
  }

  for (final file in sheet.files) {
    writeLine('FILE ${q(file.filename)} ${file.fileType.toLabel()}');

    for (final track in file.tracks) {
      writeLine(
          '  TRACK ${track.trackNumber.toString().padLeft(2, '0')} ${track.trackType.toLabel()}');

      if (track.title != null) writeLine('    TITLE ${q(track.title!)}');
      if (track.performer != null) {
        writeLine('    PERFORMER ${q(track.performer!)}');
      }
      if (track.songwriter != null) {
        writeLine('    SONGWRITER ${q(track.songwriter!)}');
      }
      if (track.isrc != null) writeLine('    ISRC ${track.isrc}');
      for (final entry in track.remComments.entries) {
        writeLine('    REM ${entry.key} ${entry.value}');
      }
      if (track.flags.isNotEmpty) {
        writeLine(
            '    FLAGS ${track.flags.map((f) => f.toToken()).join(' ')}');
      }
      if (track.pregap != null) writeLine('    PREGAP ${formatMsf(track.pregap!)}');

      // Write indices sorted by index number.
      final sortedIndices = track.indices.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      for (final entry in sortedIndices) {
        writeLine(
            '    INDEX ${entry.key.toString().padLeft(2, '0')} ${formatMsf(entry.value)}');
      }

      if (track.postgap != null) writeLine('    POSTGAP ${formatMsf(track.postgap!)}');
    }
  }

  return buf.toString();
}
