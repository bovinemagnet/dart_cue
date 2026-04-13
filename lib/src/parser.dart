/// Core CUE sheet parser — works purely from a [String], no I/O.
library;

import 'models.dart';
import 'msf.dart';

// ---------------------------------------------------------------------------
// Public entry point
// ---------------------------------------------------------------------------

/// Parse a CUE sheet from [content].
///
/// Returns `null` when [content] is blank or contains no recognisable data.
CueSheet? parseCueSheet(String content) {
  final lines = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  return _Parser(lines).parse();
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

class _Parser {
  final List<String> _lines;

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

  _Parser(this._lines);

  CueSheet? parse() {
    for (final raw in _lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
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
      _currentFileType = CueFileType.fromString(m.group(2)!);
      return;
    }

    // TRACK
    m = _reTrack.firstMatch(line);
    if (m != null) {
      _finaliseTrack();
      _currentTrack = _TrackBuilder(
        int.parse(m.group(1)!),
        CueTrackType.fromString(m.group(2)!),
      );
      return;
    }

    // INDEX
    m = _reIndex.firstMatch(line);
    if (m != null) {
      final idx = int.parse(m.group(1)!);
      final ts = parseMsf(m.group(2)!);
      if (ts != null && _currentTrack != null) {
        _currentTrack!.indices[idx] = ts;
      }
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
    if (m != null && _currentTrack != null) {
      _currentTrack!.isrc = m.group(1)!;
      return;
    }

    // PREGAP
    m = _rePregap.firstMatch(line);
    if (m != null && _currentTrack != null) {
      _currentTrack!.pregap = parseMsf(m.group(1)!);
      return;
    }

    // POSTGAP
    m = _rePostgap.firstMatch(line);
    if (m != null && _currentTrack != null) {
      _currentTrack!.postgap = parseMsf(m.group(1)!);
      return;
    }

    // FLAGS
    m = _reFlags.firstMatch(line);
    if (m != null && _currentTrack != null) {
      for (final token in m.group(1)!.trim().split(RegExp(r'\s+'))) {
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
