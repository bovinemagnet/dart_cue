/// Diagnostics types reported alongside a parsed `CueSheet`.
///
/// The default `parseCueSheet` is permissive and discards information
/// about skipped/malformed input. Consumers who need to surface warnings
/// to users should call `parseCueSheetWithDiagnostics` instead.
library;

import 'models.dart';

/// Severity of a single [CueIssue].
enum CueIssueSeverity {
  /// Non-fatal: parsing continued and valid data is still present.
  warning,

  /// Fatal: parsing could not recover meaningfully at this point.
  error,
}

/// A single diagnostic emitted during parsing or post-parse validation.
class CueIssue {
  /// 1-based line number in the source text (after CRLF normalisation).
  /// `null` for post-parse structural issues discovered after parsing.
  final int? line;

  /// Severity of the issue.
  final CueIssueSeverity severity;

  /// Human-readable description.
  final String message;

  /// The offending raw line, where relevant. `null` for post-parse
  /// issues and for issues that are not line-bound.
  final String? rawLine;

  const CueIssue({
    this.line,
    required this.severity,
    required this.message,
    this.rawLine,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CueIssue &&
          line == other.line &&
          severity == other.severity &&
          message == other.message &&
          rawLine == other.rawLine;

  @override
  int get hashCode => Object.hash(line, severity, message, rawLine);

  @override
  String toString() {
    final prefix = line == null ? '' : 'line $line: ';
    return '${severity.name.toUpperCase()}: $prefix$message';
  }
}

/// The result of `parseCueSheetWithDiagnostics`.
///
/// [sheet] is the parsed sheet (or `null` if the input had no recognisable
/// data); [issues] is the list of diagnostics emitted during parsing and
/// post-parse validation. An empty list means the sheet looks well-formed.
class ParseResult {
  final CueSheet? sheet;
  final List<CueIssue> issues;

  const ParseResult({this.sheet, required this.issues});

  /// `true` when [issues] contains at least one
  /// [CueIssueSeverity.error] or [CueIssueSeverity.warning].
  bool get hasIssues => issues.isNotEmpty;
}
