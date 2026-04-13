# dart_cue

A pure Dart [CUE sheet] parser and serialiser. Reads album, track and index
metadata into a well-typed model, writes it back losslessly, and tolerates the
quirks of real-world CUE files produced by EAC, cdrdao, XLD and friends.

No runtime dependencies. Works on the Dart VM, AOT binaries, Flutter and the
web.

[CUE sheet]: https://en.wikipedia.org/wiki/Cue_sheet_(computing)

## Features

- Parse from a `String`, raw bytes, or a file path.
- Serialise a `CueSheet` back to CUE text (`toCueString`) with frame-accurate
  round-trip.
- Full coverage of standard commands: `CATALOG`, `CDTEXTFILE`, `PERFORMER`,
  `SONGWRITER`, `TITLE`, `FILE`, `TRACK`, `INDEX`, `PREGAP`, `POSTGAP`,
  `ISRC`, `FLAGS`, `REM` (album- and track-scoped).
- File types: `WAVE`, `MP3`, `AIFF`, `AIFC`, `BINARY`, `MOTOROLA`.
- Track types: `AUDIO`, `CDG`, `MODE1/2048`, `MODE1/2352`, `MODE2/2336`,
  `MODE2/2352`, `CDI/2336`, `CDI/2352`, `DATA`.
- Flags: `DCP`, `4CH`, `PRE`, `SCMS`, `DATA`.
- MSF (`mm:ss:ff`, 75 fps) timestamps with rounding-safe `parseMsf` /
  `formatMsf`.
- Automatic `endTime` and `duration` derivation per track.
- Encoding detection: UTF-8, UTF-16 LE and UTF-16 BE byte-order marks are
  handled; falls back to Latin-1 for legacy Windows rippers.
- Permissive parsing — malformed timestamps, unknown tokens and misplaced
  commands never throw; valid data is preserved.
- Unmodifiable collections on parsed sheets — safe to share across isolates
  and cache layers without defensive copies.
- Structural `==` / `hashCode` / `toString` on `CueSheet`, `CueFile` and
  `CueTrack` — parsed sheets can be compared, put in `Set`s, or keyed in
  `Map`s by their content.
- ReplayGain helpers: `replayGainAlbumGain` / `replayGainAlbumPeak` on
  `CueSheet` and `replayGainTrackGain` / `replayGainTrackPeak` on
  `CueTrack` parse the standard `REM REPLAYGAIN_*` fields to `double`.

## Install

```yaml
dependencies:
  dart_cue: ^0.0.3
```

## Usage

### Parse a file

```dart
import 'package:dart_cue/dart_cue.dart';

Future<void> main() async {
  final sheet = await parseCueFile('album.cue');
  if (sheet == null) return;

  print('${sheet.performer} — ${sheet.title}');
  for (final file in sheet.files) {
    for (final track in file.tracks) {
      print('  ${track.trackNumber}. ${track.title} '
          '(${track.duration})');
    }
  }
}
```

### Parse a string or bytes

```dart
final sheet = parseCueSheet(cueText);
final sheet2 = parseCueBytes(Uint8List.fromList(utf8.encode(cueText)));
```

### Round-trip

```dart
final sheet = parseCueSheet(input)!;
final output = toCueString(sheet); // re-parseable, lossless
```

### MSF timestamps

```dart
final d = parseMsf('04:12:37');        // Duration
final s = formatMsf(Duration(minutes: 1, seconds: 5)); // '01:05:00'
```

### Data model at a glance

```
CueSheet
├── performer, title, songwriter, catalog, cdTextFile
├── remComments: Map<String, String>           // album-level REM
└── files: List<CueFile>
    ├── filename, fileType
    └── tracks: List<CueTrack>
        ├── trackNumber, trackType
        ├── title, performer, songwriter, isrc
        ├── pregap, postgap, flags
        ├── indices: Map<int, Duration>
        ├── remComments: Map<String, String>   // track-level REM
        └── startTime, endTime, duration       // derived
```

## CLI

The package ships a `cueinfo` executable. Install it globally:

```console
$ dart pub global activate dart_cue
$ cueinfo --help
```

Or run it from a cloned repo with `dart run bin/cueinfo.dart …`.

### Subcommands

```
cueinfo info      <file.cue> [--format text|json]   # default
cueinfo validate  <file.cue>                        # exit 0 = clean, 1 = issues
cueinfo reformat  <file.cue>                        # canonical CUE to stdout
cueinfo tracks    <file.cue>                        # one line per track
```

Examples:

```console
$ cueinfo info album.cue --format text
Title     : Great Album
Performer : The Artist
...

$ cueinfo validate album.cue
album.cue: OK

$ cueinfo validate broken.cue
broken.cue: TRACK 01: missing INDEX 01
broken.cue: CATALOG "123" is not 13 digits

$ cueinfo reformat messy.cue > clean.cue     # normalise formatting

$ cueinfo tracks album.cue
01  03:42:15  The Artist — First Song
02  04:03:30  The Artist — Second Song
```

`validate` checks: missing `INDEX 01`, non-monotonic track numbers,
out-of-range track numbers, empty filenames, missing tracks, and malformed
`CATALOG` / `ISRC` values. Exits non-zero on any issue, so it's suitable for
CI pipelines.

## Testing

```console
$ dart test
```

The suite includes malformed-input fuzzing, immutability contracts, a public
API surface check, and end-to-end fixtures under `test/fixtures/` modelled on
EAC, cdrdao, per-track WAV and hidden-pregap layouts.

## Author

Paul Snow

## Licence

Apache License 2.0. See [LICENSE](LICENSE).
