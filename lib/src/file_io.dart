/// Conditional-imports facade for `parseCueFile`.
///
/// Resolves to the VM implementation (`dart:io`-backed) when available,
/// or to a stub that throws `UnsupportedError` on the web.
library;

export 'file_io_stub.dart' if (dart.library.io) 'file_io_vm.dart';
