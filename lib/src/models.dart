/// Data models for CUE sheet parsing.
library;

import 'msf.dart';

// ---------------------------------------------------------------------------
// Internal deep-equality helpers
// ---------------------------------------------------------------------------

bool _listEq<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEq<K, V>(Map<K, V> a, Map<K, V> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) return false;
  }
  return true;
}

bool _setEq<T>(Set<T> a, Set<T> b) {
  if (identical(a, b)) return true;
  return a.length == b.length && a.containsAll(b);
}

int _listHash<T>(List<T> xs) => Object.hashAll(xs);
int _mapHash<K, V>(Map<K, V> m) =>
    Object.hashAllUnordered(m.entries.map((e) => Object.hash(e.key, e.value)));
int _setHash<T>(Set<T> s) => Object.hashAllUnordered(s);

// ---------------------------------------------------------------------------
// ReplayGain parsing
// ---------------------------------------------------------------------------

/// Strip a trailing ` dB` suffix (case-insensitive, optional space) and
/// parse the remainder as a double. Returns `null` for `null` input or an
/// unparseable value.
double? _parseGain(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  final match =
      RegExp(r'^(.*?)(\s*dB)?$', caseSensitive: false).firstMatch(trimmed);
  final numericPart = (match?.group(1) ?? trimmed).trim();
  return double.tryParse(numericPart);
}

double? _parsePeak(String? value) =>
    value == null ? null : double.tryParse(value.trim());

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

  /// ReplayGain track gain in decibels, parsed from
  /// `REM REPLAYGAIN_TRACK_GAIN`. Returns `null` when absent or
  /// unparseable.
  double? get replayGainTrackGain =>
      _parseGain(remComments['REPLAYGAIN_TRACK_GAIN']);

  /// ReplayGain track peak sample value, parsed from
  /// `REM REPLAYGAIN_TRACK_PEAK`. Returns `null` when absent or
  /// unparseable.
  double? get replayGainTrackPeak =>
      _parsePeak(remComments['REPLAYGAIN_TRACK_PEAK']);

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

  /// Structural equality across every field, including [endTime].
  ///
  /// Note: [endTime] is mutable (populated by [parseCueSheet] after all
  /// tracks in a file are known). Mutating it after inserting a [CueTrack]
  /// into a `Set` or `Map` invalidates the stored hash — the usual contract
  /// for mutable-keyed collections applies.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CueTrack &&
          trackNumber == other.trackNumber &&
          trackType == other.trackType &&
          title == other.title &&
          performer == other.performer &&
          songwriter == other.songwriter &&
          isrc == other.isrc &&
          pregap == other.pregap &&
          postgap == other.postgap &&
          endTime == other.endTime &&
          _setEq(flags, other.flags) &&
          _mapEq(indices, other.indices) &&
          _mapEq(remComments, other.remComments);

  @override
  int get hashCode => Object.hash(
        trackNumber,
        trackType,
        title,
        performer,
        songwriter,
        isrc,
        pregap,
        postgap,
        endTime,
        _setHash(flags),
        _mapHash(indices),
        _mapHash(remComments),
      );

  @override
  String toString() => 'CueTrack(#$trackNumber ${trackType.toLabel()}'
      '${title == null ? '' : ' "$title"'})';

  /// Returns a copy of this track with the given fields replaced. Fields
  /// left as `null` keep their current value (standard Dart `copyWith`
  /// semantics — there is no way to clear a nullable field via this
  /// method; construct directly for that).
  CueTrack copyWith({
    int? trackNumber,
    CueTrackType? trackType,
    String? title,
    String? performer,
    String? songwriter,
    String? isrc,
    Duration? pregap,
    Duration? postgap,
    Set<CueFlag>? flags,
    Map<int, Duration>? indices,
    Map<String, String>? remComments,
    Duration? endTime,
  }) {
    final next = CueTrack(
      trackNumber: trackNumber ?? this.trackNumber,
      trackType: trackType ?? this.trackType,
      title: title ?? this.title,
      performer: performer ?? this.performer,
      songwriter: songwriter ?? this.songwriter,
      isrc: isrc ?? this.isrc,
      pregap: pregap ?? this.pregap,
      postgap: postgap ?? this.postgap,
      flags: flags ?? this.flags,
      indices: indices ?? this.indices,
      remComments: remComments ?? this.remComments,
    );
    next.endTime = endTime ?? this.endTime;
    return next;
  }

  /// Serialise this track to a JSON-compatible map.
  ///
  /// Optional fields are omitted when null. MSF durations are written as
  /// `mm:ss:ff` strings, enums as their CUE labels, and `indices` keys
  /// are stringified so the map is JSON-safe.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'trackNumber': trackNumber,
      'trackType': trackType.toLabel(),
      if (title != null) 'title': title,
      if (performer != null) 'performer': performer,
      if (songwriter != null) 'songwriter': songwriter,
      if (isrc != null) 'isrc': isrc,
      if (pregap != null) 'pregap': formatMsf(pregap!),
      if (postgap != null) 'postgap': formatMsf(postgap!),
      if (flags.isNotEmpty) 'flags': flags.map((f) => f.toToken()).toList(),
      if (indices.isNotEmpty)
        'indices': {
          for (final entry in indices.entries)
            entry.key.toString(): formatMsf(entry.value),
        },
      if (remComments.isNotEmpty) 'remComments': Map.of(remComments),
      if (endTime != null) 'endTime': formatMsf(endTime!),
    };
  }

  /// Rehydrate a [CueTrack] from the map produced by [toJson].
  static CueTrack fromJson(Map<String, Object?> json) {
    final indicesRaw = json['indices'] as Map<String, Object?>?;
    final flagsRaw = json['flags'] as List<Object?>?;
    final remRaw = json['remComments'] as Map<String, Object?>?;
    final track = CueTrack(
      trackNumber: json['trackNumber']! as int,
      trackType: CueTrackType.fromString(json['trackType']! as String),
      title: json['title'] as String?,
      performer: json['performer'] as String?,
      songwriter: json['songwriter'] as String?,
      isrc: json['isrc'] as String?,
      pregap: _parseMsfOrNull(json['pregap'] as String?),
      postgap: _parseMsfOrNull(json['postgap'] as String?),
      flags: flagsRaw == null
          ? const {}
          : {
              for (final token in flagsRaw)
                if (CueFlag.fromToken(token! as String) case final flag?) flag,
            },
      indices: indicesRaw == null
          ? const {}
          : {
              for (final entry in indicesRaw.entries)
                int.parse(entry.key):
                    parseMsf(entry.value! as String) ?? Duration.zero,
            },
      remComments: remRaw == null
          ? const {}
          : {for (final e in remRaw.entries) e.key: e.value! as String},
    );
    track.endTime = _parseMsfOrNull(json['endTime'] as String?);
    return track;
  }
}

Duration? _parseMsfOrNull(String? s) => s == null ? null : parseMsf(s);

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CueFile &&
          filename == other.filename &&
          fileType == other.fileType &&
          _listEq(tracks, other.tracks);

  @override
  int get hashCode => Object.hash(filename, fileType, _listHash(tracks));

  @override
  String toString() =>
      'CueFile("$filename" ${fileType.toLabel()}, ${tracks.length} tracks)';

  /// Returns a copy with any given field replaced. Omitted fields keep
  /// their current value.
  CueFile copyWith({
    String? filename,
    CueFileType? fileType,
    List<CueTrack>? tracks,
  }) =>
      CueFile(
        filename: filename ?? this.filename,
        fileType: fileType ?? this.fileType,
        tracks: tracks ?? this.tracks,
      );

  /// Serialise to a JSON-compatible map.
  Map<String, Object?> toJson() => <String, Object?>{
        'filename': filename,
        'fileType': fileType.toLabel(),
        'tracks': [for (final t in tracks) t.toJson()],
      };

  /// Rehydrate from the map produced by [toJson].
  static CueFile fromJson(Map<String, Object?> json) {
    final tracksRaw = json['tracks'] as List<Object?>?;
    return CueFile(
      filename: json['filename']! as String,
      fileType: CueFileType.fromString(json['fileType']! as String),
      tracks: tracksRaw == null
          ? const []
          : [
              for (final t in tracksRaw)
                CueTrack.fromJson(t! as Map<String, Object?>)
            ],
    );
  }
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

  /// Disc barcode from [catalog], `REM UPC`, or `REM BARCODE`, in that
  /// priority order. Returns `null` if none are present.
  ///
  /// Use this when you want the barcode regardless of which command the
  /// ripper used to emit it — many real-world tools (foobar2000, some
  /// dBpoweramp and EAC plugins) put the UPC/EAN-13 barcode in a `REM`
  /// field instead of `CATALOG`. Use [catalog] directly if you
  /// specifically need the spec-defined `CATALOG` value.
  String? get barcode =>
      catalog ?? remComments['UPC'] ?? remComments['BARCODE'];

  /// ReplayGain album gain in decibels, parsed from
  /// `REM REPLAYGAIN_ALBUM_GAIN`. Returns `null` when absent or
  /// unparseable.
  double? get replayGainAlbumGain =>
      _parseGain(remComments['REPLAYGAIN_ALBUM_GAIN']);

  /// ReplayGain album peak sample value, parsed from
  /// `REM REPLAYGAIN_ALBUM_PEAK`. Returns `null` when absent or
  /// unparseable.
  double? get replayGainAlbumPeak =>
      _parsePeak(remComments['REPLAYGAIN_ALBUM_PEAK']);

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CueSheet &&
          performer == other.performer &&
          title == other.title &&
          songwriter == other.songwriter &&
          catalog == other.catalog &&
          cdTextFile == other.cdTextFile &&
          _listEq(files, other.files) &&
          _mapEq(remComments, other.remComments);

  @override
  int get hashCode => Object.hash(
        performer,
        title,
        songwriter,
        catalog,
        cdTextFile,
        _listHash(files),
        _mapHash(remComments),
      );

  @override
  String toString() {
    final trackCount = files.fold<int>(0, (sum, f) => sum + f.tracks.length);
    return 'CueSheet('
        '${title == null ? '' : '"$title" '}'
        '${files.length} files, $trackCount tracks)';
  }

  /// Returns a copy with any given field replaced. Omitted fields keep
  /// their current value.
  CueSheet copyWith({
    String? performer,
    String? title,
    String? songwriter,
    String? catalog,
    String? cdTextFile,
    List<CueFile>? files,
    Map<String, String>? remComments,
  }) =>
      CueSheet(
        performer: performer ?? this.performer,
        title: title ?? this.title,
        songwriter: songwriter ?? this.songwriter,
        catalog: catalog ?? this.catalog,
        cdTextFile: cdTextFile ?? this.cdTextFile,
        files: files ?? this.files,
        remComments: remComments ?? this.remComments,
      );

  /// Serialise to a JSON-compatible map.
  ///
  /// Optional fields are omitted when null. MSF durations are written as
  /// `mm:ss:ff` strings, enums as their CUE labels, and `indices` keys
  /// stringified so the map is JSON-safe. Round-trips losslessly via
  /// [CueSheet.fromJson].
  Map<String, Object?> toJson() => <String, Object?>{
        if (performer != null) 'performer': performer,
        if (title != null) 'title': title,
        if (songwriter != null) 'songwriter': songwriter,
        if (catalog != null) 'catalog': catalog,
        if (cdTextFile != null) 'cdTextFile': cdTextFile,
        if (remComments.isNotEmpty) 'remComments': Map.of(remComments),
        'files': [for (final f in files) f.toJson()],
      };

  /// Rehydrate from the map produced by [toJson].
  static CueSheet fromJson(Map<String, Object?> json) {
    final filesRaw = json['files'] as List<Object?>?;
    final remRaw = json['remComments'] as Map<String, Object?>?;
    return CueSheet(
      performer: json['performer'] as String?,
      title: json['title'] as String?,
      songwriter: json['songwriter'] as String?,
      catalog: json['catalog'] as String?,
      cdTextFile: json['cdTextFile'] as String?,
      files: filesRaw == null
          ? const []
          : [
              for (final f in filesRaw)
                CueFile.fromJson(f! as Map<String, Object?>)
            ],
      remComments: remRaw == null
          ? const {}
          : {for (final e in remRaw.entries) e.key: e.value! as String},
    );
  }
}
