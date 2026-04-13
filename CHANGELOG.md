# Changelog

## 0.0.5

- Web platform support. `parseCueSheet`, `parseCueBytes`, `toCueString`
  and every model class now compile to JS and run in the browser.
  Filesystem access via `parseCueFile` is behind conditional imports —
  available on the Dart VM and Flutter (mobile, desktop) as before; on
  the web it throws `UnsupportedError` with a clear message pointing
  callers at `parseCueBytes`. Closes #6.
- `parseCueSheetWithDiagnostics(String)` returns a `ParseResult { sheet,
  issues }` with line-numbered warnings for unknown FILE/TRACK/FLAGS
  tokens, malformed INDEX/PREGAP/POSTGAP timestamps, out-of-place
  commands and non-numeric TRACK numbers. The default `parseCueSheet`
  stays permissive and silent. Structural checks (missing `INDEX 01`,
  non-monotonic track numbers, malformed `CATALOG`/`ISRC`, …) are also
  exposed as `validateCueSheet(CueSheet)` for hand-built sheets. New
  exported types: `CueIssue`, `CueIssueSeverity`, `ParseResult`. The
  `cueinfo validate` subcommand now uses the library implementation.
  Closes #4.

## 0.0.4

- Fix pub.dev scoring: escape angle brackets in `bin/cueinfo.dart` doc
  comments, wrap single-statement `if` bodies in blocks to satisfy
  `curly_braces_in_flow_control_structures`, and re-run `dart format`
  across the tree. No behavioural changes.

## 0.0.3

- `CueSheet.replayGainAlbumGain` / `replayGainAlbumPeak` and
  `CueTrack.replayGainTrackGain` / `replayGainTrackPeak` convenience
  getters. Strip an optional ` dB` suffix (case-insensitive) from the gain
  values and return `double?`. Closes #5.

## 0.0.2

- `CueSheet`, `CueFile` and `CueTrack` now have structural `==`, `hashCode`
  and `toString` implementations, so parsed sheets can be compared, put in
  `Set`s, or keyed in `Map`s by their content. Equality covers every
  constructor field plus the mutable `CueTrack.endTime`. Closes #3.

## 0.0.1

Initial release.

### Features

- Parse CUE sheets from a `String` (`parseCueSheet`), raw bytes
  (`parseCueBytes`) or a file path (`parseCueFile`).
- Serialise a `CueSheet` back to CUE-format text with `toCueString`; lossless
  round-trip for all supported constructs.
- Album-level metadata: `CATALOG`, `CDTEXTFILE`, `PERFORMER`, `SONGWRITER`,
  `TITLE`, arbitrary and well-known `REM` fields (`GENRE`, `DATE`/`YEAR`,
  `DISCNUMBER`, `DISCID`, `COMMENT`, …).
- `CueSheet.barcode` convenience getter that falls back through `CATALOG` →
  `REM UPC` → `REM BARCODE` for callers that just want the disc barcode
  regardless of which command the ripper used (#2).
- File types: `WAVE`, `MP3`, `AIFF`, `AIFC`, `BINARY`, `MOTOROLA`.
- Track types: `AUDIO`, `CDG`, `MODE1/2048`, `MODE1/2352`, `MODE2/2336`,
  `MODE2/2352`, `CDI/2336`, `CDI/2352`, `DATA`.
- Track-level `TITLE`, `PERFORMER`, `SONGWRITER`, `ISRC`, `PREGAP`, `POSTGAP`,
  multiple `INDEX` entries, track-scoped `REM` comments (including
  `REPLAYGAIN_TRACK_*`).
- `FLAGS`: `DCP`, `4CH`, `PRE`, `SCMS`, `DATA`.
- MSF (`mm:ss:ff`, 75 fps) parse/format with frame-accurate round-trip.
- Automatic derivation of each track's `endTime` and `duration` from the next
  track's `INDEX 01`.
- Encoding handling: UTF-8 / UTF-16 LE / UTF-16 BE byte-order marks detected
  and stripped; Latin-1 fallback for legacy Windows-ripper sheets.
- Permissive parser: malformed MSF values, unknown tokens, out-of-place
  commands and mixed-case keywords are tolerated without throwing.
- `cueinfo` CLI (installable via `dart pub global activate dart_cue`) with
  `info`, `validate`, `reformat` and `tracks` subcommands.
- Parsed `CueSheet` collections (`files`, `remComments`, `tracks`, `indices`,
  `flags`) are unmodifiable, so the model is safe to share across isolates
  without defensive copies.
