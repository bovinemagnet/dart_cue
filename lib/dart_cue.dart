/// dart_cue — Pure Dart CUE sheet parser.
///
/// ## Quick start
///
/// ```dart
/// import 'package:dart_cue/dart_cue.dart';
///
/// void main() async {
///   final sheet = await parseCueFile('album.cue');
///   print(sheet?.title);
/// }
/// ```
library dart_cue;

export 'src/models.dart';
export 'src/msf.dart';
export 'src/parser.dart' show parseCueSheet;
export 'src/file_reader.dart' show parseCueFile, parseCueBytes;
export 'src/writer.dart' show toCueString;
