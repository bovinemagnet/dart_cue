/// Core CUE sheet parser — works purely from a [String], no I/O.
library;

import 'diagnostics.dart';
import 'models.dart';
import 'msf.dart';

// ---------------------------------------------------------------------------
// Public entry points
// ---------------------------------------------------------------------------

/// Parse a CUE sheet from [content].
///
/// Returns `null` when [content] is blank or contains no recognisable data.
/// This entry point is permissive and discards information about any
/// skipped or malformed input — use [parseCueSheetWithDiagnostics] if you
/// need to surface warnings.
CueSheet? parseCueSheet(String content) {
  final issues = <CueIssue>[];
  return _Parser(_normalise(content), issues).parse();
}

/// Parse [content] and return both the sheet (or `null` if there is none)
/// and a list of diagnostics describing silently-dropped tokens,
/// malformed timestamps, and post-parse structural problems.
///
/// The parser itself remains permissive: issues are reported but valid
/// data is still preserved. Call this when you want to show the user a
/// list of warnings ("this CUE sheet has 3 problems") without giving up
/// on the sheet.
ParseResult parseCueSheetWithDiagnostics(String content) {
  final issues = <CueIssue>[];
  final sheet = _Parser(_normalise(content), issues).parse();
  if (sheet != null) {
    issues.addAll(validateCueSheet(sheet));
  }
  return ParseResult(sheet: sheet, issues: List.unmodifiable(issues));
}

List<String> _normalise(String content) =>
    content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');

// ---------------------------------------------------------------------------
// Post-parse structural validation
// ---------------------------------------------------------------------------

/// Check a parsed [sheet] for structural problems (missing `INDEX 01`,
/// non-monotonic track numbers, malformed `CATALOG` / `ISRC`, …) and
/// return the list of issues. Returns an empty list when the sheet is
/// well-formed.
///
/// Produces the post-parse slice of what [parseCueSheetWithDiagnostics]
/// emits; exposed separately so callers can validate sheets that were
/// built by hand rather than parsed.
List<CueIssue> validateCueSheet(CueSheet sheet) {
  final issues = <CueIssue>[];

  if (sheet.files.isEmpty) {
    issues.add(const CueIssue(
      severity: CueIssueSeverity.warning,
      message: 'no FILE entries',
    ));
  }

  if (sheet.catalog != null && !RegExp(r'^\d{13}$').hasMatch(sheet.catalog!)) {
    issues.add(CueIssue(
      severity: CueIssueSeverity.warning,
      message: 'CATALOG "${sheet.catalog}" is not 13 digits',
    ));
  }

  int? previousTrackNumber;
  for (final file in sheet.files) {
    if (file.filename.isEmpty) {
      issues.add(const CueIssue(
        severity: CueIssueSeverity.warning,
        message: 'FILE entry has empty filename',
      ));
    }
    if (file.tracks.isEmpty) {
      issues.add(CueIssue(
        severity: CueIssueSeverity.warning,
        message: 'FILE "${file.filename}" has no tracks',
      ));
    }
    for (final t in file.tracks) {
      final where = 'TRACK ${t.trackNumber.toString().padLeft(2, '0')}';
      if (t.trackNumber < 1 || t.trackNumber > 99) {
        issues.add(CueIssue(
          severity: CueIssueSeverity.warning,
          message: '$where: track number out of range (1-99)',
        ));
      }
      if (previousTrackNumber != null && t.trackNumber <= previousTrackNumber) {
        issues.add(CueIssue(
          severity: CueIssueSeverity.warning,
          message: '$where: track number does not increase monotonically',
        ));
      }
      previousTrackNumber = t.trackNumber;

      if (!t.indices.containsKey(1)) {
        issues.add(CueIssue(
          severity: CueIssueSeverity.warning,
          message: '$where: missing INDEX 01',
        ));
      }
      if (t.isrc != null &&
          !RegExp(r'^[A-Z]{2}[A-Z0-9]{3}\d{7}$').hasMatch(t.isrc!)) {
        issues.add(CueIssue(
          severity: CueIssueSeverity.warning,
          message: '$where: ISRC "${t.isrc}" is malformed',
        ));
      }
    }
  }
  return issues;
}

// ---------------------------------------------------------------------------
// Internal parser
// ---------------------------------------------------------------------------

// Regex helpers
final _reQuoted = RegExp(r'^"(.*)"$');
final _rePerformer = RegExp(r'^PERFORMER\s+(.+)$', caseSensitive: false);
final _reTitle = RegExp(r'^TITLE\s+(.+)$', caseSensitive: false);
final _reSongwriter = RegExp(r'^SONGWRITER\s+(.+)$', caseSensitive: false);
final _reCatalog = RegExp(r'^CATALOG\s+(\S+)$', caseSensitive: false);
final _reCdTextFile = RegExp(r'^CDTEXTFILE\s+(.+)$', caseSensitive: false);
final _reFile = RegExp(r'^FILE\s+(.+)\s+(\S+)$', caseSensitive: false);
final _reTrack = RegExp(r'^TRACK\s+(\d+)\s+(\S+)$', caseSensitive: false);
final _reIndex = RegExp(r'^INDEX\s+(\d+)\s+(\S+)$', caseSensitive: false);
final _reIsrc = RegExp(r'^ISRC\s+(\S+)$', caseSensitive: false);
final _rePregap = RegExp(r'^PREGAP\s+(\S+)$', caseSensitive: false);
final _rePostgap = RegExp(r'^POSTGAP\s+(\S+)$', caseSensitive: false);
final _reFlags = RegExp(r'^FLAGS\s+(.+)$', caseSensitive: false);
final _reRem = RegExp(r'^REM\s+(\S+)(?:\s+(.*))?$', caseSensitive: false);

String _unquote(String s) {
  final m = _reQuoted.firstMatch(s.trim());
  return m != null ? m.group(1)! : s.trim();
}

class _TrackBuilder {
  int trackNumber;
  CueTrackType trackType;
  String? title;
  String? performer;
  String? songwriter;
  String? isrc;
  Duration? pregap;
  Duration? postgap;
  final Set<CueFlag> flags = {};
  final Map<int, Duration> indices = {};
  final Map<String, String> remComments = {};

  _TrackBuilder(this.trackNumber, this.trackType);

  CueTrack build() => CueTrack(
        trackNumber: trackNumber,
        trackType: trackType,
        title: title,
        performer: performer,
        songwriter: songwriter,
        isrc: isrc,
        pregap: pregap,
        postgap: postgap,
        flags: Set.unmodifiable(flags),
        indices: Map.unmodifiable(indices),
        remComments: Map.unmodifiable(remComments),
      );
}

// Known tokens — anything else triggers a warning when diagnostics are on.
const _knownFileTypes = {'WAVE', 'MP3', 'AIFF', 'AIFC', 'BINARY', 'MOTOROLA'};
const _knownTrackTypes = {
  'AUDIO',
  'CDG',
  'MODE1/2048',
  'MODE1/2352',
  'MODE2/2336',
  'MODE2/2352',
  'CDI/2336',
  'CDI/2352',
  'DATA',
};
const _knownFlags = {'DCP', '4CH', 'PRE', 'SCMS', 'DATA'};

final _reTrackLoose = RegExp(r'^TRACK\s+\S+\s+\S+$', caseSensitive: false);
final _reIndexLoose = RegExp(r'^INDEX\s+\S+\s+\S+$', caseSensitive: false);

class _Parser {
  final List<String> _lines;
  final List<CueIssue> _issues;
  int _currentLineNo = 0;
  String _currentRaw = '';

  // Album-level state
  String? _performer;
  String? _title;
  String? _songwriter;
  String? _catalog;
  String? _cdTextFile;
  final Map<String, String> _remComments = {};

  // File / track accumulation
  final List<CueFile> _files = [];
  String? _currentFilename;
  CueFileType _currentFileType = CueFileType.wave;
  final List<_TrackBuilder> _currentTracks = [];

  _TrackBuilder? _currentTrack;

  _Parser(this._lines, this._issues);

  void _warn(String message) {
    _issues.add(CueIssue(
      line: _currentLineNo,
      severity: CueIssueSeverity.warning,
      message: message,
      rawLine: _currentRaw,
    ));
  }

  CueSheet? parse() {
    for (var i = 0; i < _lines.length; i++) {
      final raw = _lines[i];
      final line = raw.trim();
      if (line.isEmpty) continue;
      _currentLineNo = i + 1;
      _currentRaw = raw;
      _parseLine(line);
    }
    _finaliseFile();

    // Derive endTime for each track from the next track's INDEX 01.
    for (final file in _files) {
      final tracks = file.tracks;
      for (int i = 0; i < tracks.length - 1; i++) {
        tracks[i].endTime = tracks[i + 1].startTime;
      }
    }

    if (_files.isEmpty &&
        _performer == null &&
        _title == null &&
        _catalog == null) {
      return null;
    }

    return CueSheet(
      performer: _performer,
      title: _title,
      songwriter: _songwriter,
      catalog: _catalog,
      cdTextFile: _cdTextFile,
      files: List.unmodifiable(_files),
      remComments: Map.unmodifiable(_remComments),
    );
  }

  void _parseLine(String line) {
    Match? m;

    // FILE
    m = _reFile.firstMatch(line);
    if (m != null) {
      _finaliseFile();
      _currentFilename = _unquote(m.group(1)!);
      final typeToken = m.group(2)!.toUpperCase();
      if (!_knownFileTypes.contains(typeToken)) {
        _warn('unknown FILE type "$typeToken" (defaulting to WAVE)');
      }
      _currentFileType = CueFileType.fromString(typeToken);
      return;
    }

    // TRACK
    m = _reTrack.firstMatch(line);
    if (m != null) {
      _finaliseTrack();
      final typeToken = m.group(2)!.toUpperCase();
      if (!_knownTrackTypes.contains(typeToken)) {
        _warn('unknown TRACK type "$typeToken" (defaulting to AUDIO)');
      }
      _currentTrack = _TrackBuilder(
        int.parse(m.group(1)!),
        CueTrackType.fromString(typeToken),
      );
      return;
    }
    if (_reTrackLoose.hasMatch(line)) {
      _warn('malformed TRACK command (track number must be numeric)');
      return;
    }

    // INDEX
    m = _reIndex.firstMatch(line);
    if (m != null) {
      final idx = int.parse(m.group(1)!);
      final ts = parseMsf(m.group(2)!);
      if (ts == null) {
        _warn('malformed INDEX timestamp "${m.group(2)}"');
        return;
      }
      if (_currentTrack == null) {
        _warn('INDEX outside any TRACK block');
        return;
      }
      _currentTrack!.indices[idx] = ts;
      return;
    }
    if (_reIndexLoose.hasMatch(line)) {
      _warn('malformed INDEX command');
      return;
    }

    // PERFORMER (track or album)
    m = _rePerformer.firstMatch(line);
    if (m != null) {
      final val = _unquote(m.group(1)!);
      if (_currentTrack != null) {
        _currentTrack!.performer = val;
      } else {
        _performer = val;
      }
      return;
    }

    // TITLE (track or album)
    m = _reTitle.firstMatch(line);
    if (m != null) {
      final val = _unquote(m.group(1)!);
      if (_currentTrack != null) {
        _currentTrack!.title = val;
      } else {
        _title = val;
      }
      return;
    }

    // SONGWRITER (track or album)
    m = _reSongwriter.firstMatch(line);
    if (m != null) {
      final val = _unquote(m.group(1)!);
      if (_currentTrack != null) {
        _currentTrack!.songwriter = val;
      } else {
        _songwriter = val;
      }
      return;
    }

    // CATALOG
    m = _reCatalog.firstMatch(line);
    if (m != null) {
      _catalog = m.group(1)!;
      return;
    }

    // CDTEXTFILE
    m = _reCdTextFile.firstMatch(line);
    if (m != null) {
      _cdTextFile = _unquote(m.group(1)!);
      return;
    }

    // ISRC
    m = _reIsrc.firstMatch(line);
    if (m != null) {
      if (_currentTrack == null) {
        _warn('ISRC outside any TRACK block');
        return;
      }
      _currentTrack!.isrc = m.group(1)!;
      return;
    }

    // PREGAP
    m = _rePregap.firstMatch(line);
    if (m != null) {
      if (_currentTrack == null) {
        _warn('PREGAP outside any TRACK block');
        return;
      }
      final ts = parseMsf(m.group(1)!);
      if (ts == null) {
        _warn('malformed PREGAP timestamp "${m.group(1)}"');
        return;
      }
      _currentTrack!.pregap = ts;
      return;
    }

    // POSTGAP
    m = _rePostgap.firstMatch(line);
    if (m != null) {
      if (_currentTrack == null) {
        _warn('POSTGAP outside any TRACK block');
        return;
      }
      final ts = parseMsf(m.group(1)!);
      if (ts == null) {
        _warn('malformed POSTGAP timestamp "${m.group(1)}"');
        return;
      }
      _currentTrack!.postgap = ts;
      return;
    }

    // FLAGS
    m = _reFlags.firstMatch(line);
    if (m != null) {
      if (_currentTrack == null) {
        _warn('FLAGS outside any TRACK block');
        return;
      }
      for (final token in m.group(1)!.trim().split(RegExp(r'\s+'))) {
        final upper = token.toUpperCase();
        if (!_knownFlags.contains(upper)) {
          _warn('unknown FLAGS token "$token"');
          continue;
        }
        final flag = CueFlag.fromToken(token);
        if (flag != null) _currentTrack!.flags.add(flag);
      }
      return;
    }

    // REM
    m = _reRem.firstMatch(line);
    if (m != null) {
      final key = m.group(1)!.toUpperCase();
      final val = m.group(2)?.trim() ?? '';
      if (_currentTrack != null) {
        _currentTrack!.remComments[key] = _unquote(val);
      } else {
        _remComments[key] = _unquote(val);
      }
      return;
    }
  }

  void _finaliseTrack() {
    if (_currentTrack != null) {
      _currentTracks.add(_currentTrack!);
      _currentTrack = null;
    }
  }

  void _finaliseFile() {
    _finaliseTrack();
    if (_currentFilename != null || _currentTracks.isNotEmpty) {
      _files.add(CueFile(
        filename: _currentFilename ?? '',
        fileType: _currentFileType,
        tracks: List.unmodifiable(
          _currentTracks.map((b) => b.build()).toList(),
        ),
      ));
    }
    _currentFilename = null;
    _currentFileType = CueFileType.wave;
    _currentTracks.clear();
  }
}
