import 'package:bill_splitter/features/bill/compute/rounding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FR-015: whole-number values are returned unchanged', () {
    expect(roundUpEgp(0), 0);
    expect(roundUpEgp(15), 15);
    expect(roundUpEgp(1000), 1000);
  });

  test('FR-015: fractional values round UP, never down', () {
    expect(roundUpEgp(0.01), 1);
    expect(roundUpEgp(15.4), 16);
    expect(roundUpEgp(15.5), 16);
    expect(roundUpEgp(15.99), 16);
  });

  test('SC-003: sum of rounded-up per-person finals ≥ raw grand total', () {
    // 3 people each owing 33.4 → after round-up, 34+34+34 = 102 ≥ 100.2.
    final raw = [33.4, 33.4, 33.4];
    final rounded = raw.map(roundUpEgp).toList();
    final rawSum = raw.fold<num>(0, (a, b) => a + b);
    final roundedSum = rounded.fold<int>(0, (a, b) => a + b);
    expect(roundedSum, greaterThanOrEqualTo(rawSum));
  });
}
