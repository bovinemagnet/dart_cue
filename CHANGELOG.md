# Changelog

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
