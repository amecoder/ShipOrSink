// Line coverage gate for an lcov file (dev-standards).
//
// Usage (pre-push hook `flutter-test`, after `flutter test --coverage`):
//   dart tool/quality_metrics/bin/coverage_check.dart coverage/lcov.info 80
//
// Sums every LF (lines found) and LH (lines hit) record; fails when
// LH / LF < minimum %, or when the file has no instrumented line.
// Limit: lcov lists only the files the tests loaded — a lib/ file no test
// imports is not in the denominator (import every lib/ file from one test
// to count it).
import 'dart:io';

void main(List<String> args) {
  final minimum = int.parse(args[1]);
  var found = 0;
  var hit = 0;
  for (final line in File(args[0]).readAsLinesSync()) {
    if (line.startsWith('LF:')) {
      found += int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      hit += int.parse(line.substring(3));
    }
  }
  if (found == 0) {
    stdout.writeln('FAIL: ${args[0]} has no instrumented lines');
    exit(1);
  }
  final percent = (hit * 100 / found).toStringAsFixed(2);
  if (hit * 100 < minimum * found) {
    stdout.writeln(
      'FAIL: line coverage $percent% ($hit/$found), min $minimum%',
    );
    exit(1);
  }
  stdout.writeln('OK: line coverage $percent% ($hit/$found), min $minimum%');
}
