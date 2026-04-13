# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Pure Dart CUE sheet parser library (album/track metadata, MSF timestamps, round-trip serialisation). No runtime dependencies; `test` is the only dev dependency. SDK `>=3.5.0 <4.0.0`.

## Commands

- Install deps: `dart pub get`
- Run all tests: `dart test`
- Run a single test file: `dart test test/parser_test.dart`
- Run a single test by name: `dart test -n "test name substring"`
- Analyse: `dart analyze`
- Format: `dart format .`
- CLI tool: `dart run bin/cueinfo.dart <file.cue> [--format text|json]`

## Architecture

The library is organised as a small pipeline, with `lib/dart_cue.dart` re-exporting the public surface:

- `src/models.dart` — Immutable data model: `CueSheet` → `CueFile` → `CueTrack` → `CueIndex`, plus enums (`CueFileType`, `CueTrackType`) and track flags. This is the shape all other layers produce/consume.
- `src/msf.dart` — `Msf` (minutes:seconds:frames, 75 fps) value type used for all CUE timestamps; handles parsing, arithmetic, and formatting.
- `src/parser.dart` — `parseCueSheet(String)` is the core entry point. It is I/O-free: takes a string, normalises line endings, and runs a line-oriented state machine (`_Parser`) driven by regexes for each CUE command (`FILE`, `TRACK`, `INDEX`, `PERFORMER`, `TITLE`, `REM`, etc.). Returns `null` for empty/unrecognised input.
- `src/file_reader.dart` — Thin I/O layer: `parseCueFile(path)` and `parseCueBytes(bytes)` handle encoding detection / BOM stripping then delegate to `parseCueSheet`.
- `src/writer.dart` — `toCueString(CueSheet)` serialises the model back to CUE text; round-trip stability is a design goal and is covered by `test/writer_test.dart`.

Keep the parser pure (no `dart:io`); any filesystem or byte-level concerns belong in `file_reader.dart`. The CLI in `bin/cueinfo.dart` is a consumer of the public API only.
