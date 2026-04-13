/// Data models for CUE sheet parsing.
library;

/// File type declared in a FILE command.
enum CueFileType {
  wave,
  mp3,
  aiff,
  aifc,
  binary,
  motorola;

  /// Parse a file-type string (case-insensitive) to [CueFileType].
  /// Returns [CueFileType.wave] for unrecognised values.
  static CueFileType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'WAVE':
        return CueFileType.wave;
      case 'MP3':
        return CueFileType.mp3;
      case 'AIFF':
        return CueFileType.aiff;
      case 'AIFC':
        return CueFileType.aifc;
      case 'BINARY':
        return CueFileType.binary;
      case 'MOTOROLA':
        return CueFileType.motorola;
      default:
        return CueFileType.wave;
    }
  }

  /// CUE-format string for this file type (e.g. `WAVE`).
  String toLabel() => name.toUpperCase();
}

/// Track data type declared in a TRACK command.
enum CueTrackType {
  audio,
  cdg,
  mode1_2048,
  mode1_2352,
  mode2_2336,
  mode2_2352,
  cdi_2336,
  cdi_2352,
  data;

  /// Parse a track-type string (case-insensitive) to [CueTrackType].
  /// Returns [CueTrackType.audio] for unrecognised values.
  static CueTrackType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'AUDIO':
        return CueTrackType.audio;
      case 'CDG':
        return CueTrackType.cdg;
      case 'MODE1/2048':
        return CueTrackType.mode1_2048;
      case 'MODE1/2352':
        return CueTrackType.mode1_2352;
      case 'MODE2/2336':
        return CueTrackType.mode2_2336;
      case 'MODE2/2352':
        return CueTrackType.mode2_2352;
      case 'CDI/2336':
        return CueTrackType.cdi_2336;
      case 'CDI/2352':
        return CueTrackType.cdi_2352;
      case 'DATA':
        return CueTrackType.data;
      default:
        return CueTrackType.audio;
    }
  }

  /// CUE-format string for this track type (e.g. `AUDIO`, `MODE1/2352`).
  String toLabel() {
    switch (this) {
      case CueTrackType.audio:
        return 'AUDIO';
      case CueTrackType.cdg:
        return 'CDG';
      case CueTrackType.mode1_2048:
        return 'MODE1/2048';
      case CueTrackType.mode1_2352:
        return 'MODE1/2352';
      case CueTrackType.mode2_2336:
        return 'MODE2/2336';
      case CueTrackType.mode2_2352:
        return 'MODE2/2352';
      case CueTrackType.cdi_2336:
        return 'CDI/2336';
      case CueTrackType.cdi_2352:
        return 'CDI/2352';
      case CueTrackType.data:
        return 'DATA';
    }
  }
}

/// Track flags declared with the FLAGS command.
enum CueFlag {
  /// Digital copy permitted.
  dcp,

  /// Four-channel audio.
  fourChannel,

  /// Pre-emphasis enabled.
  preEmphasis,

  /// Serial copy management system.
  scms,

  /// Data track.
  data;

  /// Parse a flag token (case-insensitive) to [CueFlag].
  /// Returns `null` for unrecognised tokens.
  static CueFlag? fromToken(String token) {
    switch (token.toUpperCase()) {
      case 'DCP':
        return CueFlag.dcp;
      case '4CH':
        return CueFlag.fourChannel;
      case 'PRE':
        return CueFlag.preEmphasis;
      case 'SCMS':
        return CueFlag.scms;
      case 'DATA':
        return CueFlag.data;
      default:
        return null;
    }
  }

  /// CUE-format token for this flag.
  String toToken() {
    switch (this) {
      case CueFlag.dcp:
        return 'DCP';
      case CueFlag.fourChannel:
        return '4CH';
      case CueFlag.preEmphasis:
        return 'PRE';
      case CueFlag.scms:
        return 'SCMS';
      case CueFlag.data:
        return 'DATA';
    }
  }
}

/// A single track within a CUE file entry.
class CueTrack {
  /// 1-based track number.
  final int trackNumber;

  /// Data type for this track.
  final CueTrackType trackType;

  /// Track title.
  final String? title;

  /// Track performer.
  final String? performer;

  /// Track songwriter.
  final String? songwriter;

  /// International Standard Recording Code.
  final String? isrc;

  /// Silence to be added before the track.
  final Duration? pregap;

  /// Silence to be added after the track.
  final Duration? postgap;

  /// Track flags.
  final Set<CueFlag> flags;

  /// All INDEX entries for this track.
  ///
  /// Keys are index numbers (0, 1, 2, …); values are MSF timestamps as
  /// [Duration]s.
  final Map<int, Duration> indices;

  /// Track-scoped REM key→value pairs (keys stored in uppercase). Common
  /// examples are `REPLAYGAIN_TRACK_GAIN` and `REPLAYGAIN_TRACK_PEAK`.
  final Map<String, String> remComments;

  /// Start time of this track (INDEX 01).
  Duration? get startTime => indices[1];

  /// End time derived from the next track's INDEX 01. Populated externally
  /// after all tracks have been parsed.
  Duration? endTime;

  /// Duration of this track (`endTime - startTime`), or `null` if either is
  /// unavailable.
  Duration? get duration {
    final start = startTime;
    final end = endTime;
    if (start == null || end == null) return null;
    return end - start;
  }

  CueTrack({
    required this.trackNumber,
    required this.trackType,
    this.title,
    this.performer,
    this.songwriter,
    this.isrc,
    this.pregap,
    this.postgap,
    Set<CueFlag>? flags,
    Map<int, Duration>? indices,
    Map<String, String>? remComments,
  })  : flags = flags ?? const {},
        indices = indices ?? const {},
        remComments = remComments ?? const {};
}

/// A FILE entry and its associated tracks.
class CueFile {
  /// Filename as declared in the CUE sheet (may be quoted).
  final String filename;

  /// File type (WAVE, MP3, etc.).
  final CueFileType fileType;

  /// Tracks belonging to this file.
  final List<CueTrack> tracks;

  CueFile({
    required this.filename,
    required this.fileType,
    List<CueTrack>? tracks,
  }) : tracks = tracks ?? [];
}

/// The top-level CUE sheet.
class CueSheet {
  /// Album performer.
  final String? performer;

  /// Album title.
  final String? title;

  /// Album songwriter.
  final String? songwriter;

  /// Barcode / EAN-13 catalog number.
  final String? catalog;

  /// Path to an embedded CD-Text file.
  final String? cdTextFile;

  /// All FILE entries (and their tracks).
  final List<CueFile> files;

  /// All REM key→value pairs (keys stored in uppercase).
  final Map<String, String> remComments;

  /// Genre from `REM GENRE`.
  String? get genre => remComments['GENRE'];

  /// Release date from `REM DATE` or `REM YEAR`.
  String? get date => remComments['DATE'] ?? remComments['YEAR'];

  /// Disc number from `REM DISCNUMBER`.
  int? get discNumber {
    final v = remComments['DISCNUMBER'];
    return v == null ? null : int.tryParse(v);
  }

  /// Disc ID from `REM DISCID`.
  String? get discId => remComments['DISCID'];

  CueSheet({
    this.performer,
    this.title,
    this.songwriter,
    this.catalog,
    this.cdTextFile,
    List<CueFile>? files,
    Map<String, String>? remComments,
  })  : files = files ?? [],
        remComments = remComments ?? {};
}
