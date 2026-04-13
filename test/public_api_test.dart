/// Smoke test for the public API surface.
///
/// Imports only `package:dart_cue/dart_cue.dart` and exercises every
/// exported symbol. Catches accidental removal of exports or constructors
/// when refactoring.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_cue/dart_cue.dart';
import 'package:test/test.dart';

void main() {
  test('every exported symbol is reachable', () {
    // Enums
    expect(CueFileType.values, isNotEmpty);
    expect(CueFileType.fromString('WAVE'), CueFileType.wave);
    expect(CueFileType.wave.toLabel(), 'WAVE');

    expect(CueTrackType.values, isNotEmpty);
    expect(CueTrackType.fromString('AUDIO'), CueTrackType.audio);
    expect(CueTrackType.audio.toLabel(), 'AUDIO');

    expect(CueFlag.values, isNotEmpty);
    expect(CueFlag.fromToken('DCP'), CueFlag.dcp);
    expect(CueFlag.dcp.toToken(), 'DCP');

    // MSF helpers
    expect(parseMsf('00:00:00'), Duration.zero);
    expect(formatMsf(Duration.zero), '00:00:00');

    // Constructors — the library must be usable without the parser.
    final track = CueTrack(
      trackNumber: 1,
      trackType: CueTrackType.audio,
      title: 'T',
      performer: 'P',
      songwriter: 'S',
      isrc: 'ZZABC1234567',
      pregap: parseMsf('00:02:00'),
      postgap: parseMsf('00:00:10'),
      flags: {CueFlag.dcp},
      indices: {1: Duration.zero},
      remComments: {'CUSTOM': 'x'},
    );
    final file = CueFile(
      filename: 'a.wav',
      fileType: CueFileType.wave,
      tracks: [track],
    );
    final sheet = CueSheet(
      performer: 'P',
      title: 'T',
      songwriter: 'S',
      catalog: '1234567890123',
      cdTextFile: 'cdt.cdt',
      files: [file],
      remComments: {'GENRE': 'Rock'},
    );

    // Convenience getters
    expect(sheet.genre, 'Rock');
    expect(track.startTime, Duration.zero);

    // Parser entry points
    expect(parseCueSheet(''), isNull);
    expect(
      parseCueBytes(Uint8List.fromList(utf8.encode(toCueString(sheet)))),
      isNotNull,
    );
    // parseCueFile is covered in file_reader_test.dart — we only assert the
    // symbol exists here.
    expect(parseCueFile, isA<Function>());

    // Serialiser
    final out = toCueString(sheet);
    expect(out, contains('TITLE T'));
    expect(out, contains('FILE'));
  });
}
