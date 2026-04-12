import 'package:dart_cue/dart_cue.dart';
import 'package:test/test.dart';

void main() {
  group('parseMsf', () {
    test('typical timestamp', () {
      final d = parseMsf('03:25:50');
      expect(d, isNotNull);
      // 3*60*1000 + 25*1000 + 50*1000~/75
      final expectedMs = 3 * 60 * 1000 + 25 * 1000 + 50 * 1000 ~/ 75;
      expect(d!.inMilliseconds, expectedMs);
    });

    test('zero timestamp', () {
      expect(parseMsf('00:00:00'), Duration.zero);
    });

    test('max valid frames (74)', () {
      final d = parseMsf('99:59:74');
      expect(d, isNotNull);
    });

    test('invalid format — too few parts', () {
      expect(parseMsf('03:25'), isNull);
    });

    test('invalid format — non-numeric', () {
      expect(parseMsf('aa:bb:cc'), isNull);
    });

    test('out-of-range frames (75)', () {
      expect(parseMsf('00:00:75'), isNull);
    });

    test('out-of-range seconds (60)', () {
      expect(parseMsf('00:60:00'), isNull);
    });
  });

  group('formatMsf', () {
    test('zero duration', () {
      expect(formatMsf(Duration.zero), '00:00:00');
    });

    test('round-trip — zero', () {
      expect(parseMsf(formatMsf(Duration.zero)), Duration.zero);
    });

    test('round-trip — arbitrary timestamp', () {
      final original = parseMsf('04:12:37')!;
      expect(parseMsf(formatMsf(original)), original);
    });

    test('minutes padded to two digits', () {
      final d = Duration(minutes: 1, seconds: 5);
      final s = formatMsf(d);
      expect(s.substring(0, 2), '01');
      expect(s.substring(3, 5), '05');
    });
  });
}
