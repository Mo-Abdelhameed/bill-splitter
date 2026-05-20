import 'package:bill_splitter/features/bill/compute/charge_distribution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FR-012: US-3 AC-2 — 200/100 subtotals, 30 service → 20 / 10', () {
    final out = distributeCharge(
      charge: 30,
      itemSubtotals: {'A': 200, 'B': 100},
    );
    expect(out['A'], 20);
    expect(out['B'], 10);
  });

  test('FR-012: charge proportional to subtotals (SC-004 verifiable)', () {
    final out = distributeCharge(
      charge: 60,
      itemSubtotals: {'A': 50, 'B': 100, 'C': 50},
    );
    // ratios: 50/200, 100/200, 50/200 → 15, 30, 15
    expect(out['A'], 15);
    expect(out['B'], 30);
    expect(out['C'], 15);
  });

  test('FR-013: null charge means no distribution at all', () {
    final out = distributeCharge(
      charge: null,
      itemSubtotals: {'A': 100, 'B': 100},
    );
    expect(out, isEmpty);
  });

  test('FR-012: zero charge yields zero for everyone', () {
    final out = distributeCharge(
      charge: 0,
      itemSubtotals: {'A': 100, 'B': 100},
    );
    expect(out['A'], 0);
    expect(out['B'], 0);
  });

  test('FR-012: when all subtotals are zero, charge cannot be split — empty map', () {
    final out = distributeCharge(
      charge: 50,
      itemSubtotals: {'A': 0, 'B': 0},
    );
    // No anchor for proportionality — nobody pays the charge.
    expect(out, isEmpty);
  });
}
