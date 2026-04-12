/// MSF (Minutes:Seconds:Frames) time-format utilities.
///
/// CUE sheets use the MSF format `mm:ss:ff` where `ff` is a frame count at
/// 75 frames per second.

const int _framesPerSecond = 75;

/// Parse an MSF string (`mm:ss:ff`) to a [Duration].
///
/// Returns `null` if [msf] does not match the expected format or contains
/// out-of-range values.
Duration? parseMsf(String msf) {
  final parts = msf.split(':');
  if (parts.length != 3) return null;
  final mm = int.tryParse(parts[0]);
  final ss = int.tryParse(parts[1]);
  final ff = int.tryParse(parts[2]);
  if (mm == null || ss == null || ff == null) return null;
  if (mm < 0 || ss < 0 || ss > 59 || ff < 0 || ff > 74) return null;
  final totalMs =
      mm * 60 * 1000 + ss * 1000 + ff * 1000 ~/ _framesPerSecond;
  return Duration(milliseconds: totalMs);
}

/// Format a [Duration] as an MSF string (`mm:ss:ff`).
///
/// Frames are rounded down from the sub-second millisecond value.
String formatMsf(Duration duration) {
  final totalMs = duration.inMilliseconds.abs();
  final mm = totalMs ~/ (60 * 1000);
  final ss = (totalMs % (60 * 1000)) ~/ 1000;
  final ms = totalMs % 1000;
  final ff = ms * _framesPerSecond ~/ 1000;
  return '${mm.toString().padLeft(2, '0')}:'
      '${ss.toString().padLeft(2, '0')}:'
      '${ff.toString().padLeft(2, '0')}';
}
