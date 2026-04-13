/// Default stub used on platforms without a filesystem (e.g. the browser).
///
/// The VM implementation lives in `file_io_vm.dart`; `file_io.dart`
/// chooses between them via conditional imports.
library;

import 'models.dart';

/// Platform stub: on targets without a filesystem, loading a CUE sheet by
/// path is not supported. Callers on the web should fetch the file's bytes
/// themselves and use `parseCueBytes` instead.
Future<CueSheet?> parseCueFile(String filePath) {
  throw UnsupportedError(
    'parseCueFile is not supported on this platform. '
    'Fetch the file bytes yourself and call parseCueBytes().',
  );
}
