import 'package:bill_splitter_app/logic/totals.dart';
import 'package:bill_splitter_app/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Diner _d(String id, String name) => Diner(id: id, name: name);
ReceiptItem _i(String id, String name, double price) =>
    ReceiptItem(id: id, name: name, price: price);

void main() {
  group('computeTotals', () {
    test('item split equally between two diners', () {
      final totals = computeTotals(
        diners: [_d('a', 'A'), _d('b', 'B')],
        items: [_i('x', 'X', 20.0)],
        assignments: {'x': {'a', 'b'}},
        charges: const ReceiptCharges(),
      );
      final a = totals.perDiner.firstWhere((t) => t.diner.id == 'a');
      final b = totals.perDiner.firstWhere((t) => t.diner.id == 'b');
      expect(a.subtotalCents, 1000);
      expect(b.subtotalCents, 1000);
    });

    test('diner assigned to multiple items', () {
      final totals = computeTotals(
        diners: [_d('a', 'A'), _d('b', 'B')],
        items: [_i('x', 'X', 10.0), _i('y', 'Y', 8.0)],
        assignments: {
          'x': {'a'},
          'y': {'a', 'b'},
        },
        charges: const ReceiptCharges(),
      );
      final a = totals.perDiner.firstWhere((t) => t.diner.id == 'a');
      expect(a.subtotalCents, 1400); // 10 + 4
    });

    test('proportional tax split', () {
      final totals = computeTotals(
        diners: [_d('a', 'A'), _d('b', 'B')],
        items: [_i('x', 'X', 15.0), _i('y', 'Y', 35.0)],
        assignments: {
          'x': {'a'},
          'y': {'b'},
        },
        charges: const ReceiptCharges(tax: 5.0),
      );
      final a = totals.perDiner.firstWhere((t) => t.diner.id == 'a');
      final b = totals.perDiner.firstWhere((t) => t.diner.id == 'b');
      expect(a.taxShareCents, 150);
      expect(b.taxShareCents, 350);
    });

    test('proportional service split', () {
      final totals = computeTotals(
        diners: [_d('a', 'A'), _d('b', 'B')],
        items: [_i('x', 'X', 10.0), _i('y', 'Y', 30.0)],
        assignments: {
          'x': {'a'},
          'y': {'b'},
        },
        charges: const ReceiptCharges(service: 4.0),
      );
      final a = totals.perDiner.firstWhere((t) => t.diner.id == 'a');
      final b = totals.perDiner.firstWhere((t) => t.diner.id == 'b');
      expect(a.serviceShareCents, 100);
      expect(b.serviceShareCents, 300);
    });

    test('zero tax means zero per-diner tax share', () {
      final totals = computeTotals(
        diners: [_d('a', 'A')],
        items: [_i('x', 'X', 10.0)],
        assignments: {
          'x': {'a'},
        },
        charges: const ReceiptCharges(tax: 0),
      );
      expect(totals.perDiner.single.taxShareCents, 0);
    });

    test('null tax/service treated as zero', () {
      final totals = computeTotals(
        diners: [_d('a', 'A')],
        items: [_i('x', 'X', 10.0)],
        assignments: {
          'x': {'a'},
        },
        charges: const ReceiptCharges(),
      );
      expect(totals.perDiner.single.taxShareCents, 0);
      expect(totals.perDiner.single.serviceShareCents, 0);
    });

    test('diner totals reconcile to bill total within 0.02', () {
      final totals = computeTotals(
        diners: [_d('a', 'A'), _d('b', 'B')],
        items: [_i('x', 'X', 25.0), _i('y', 'Y', 25.0)],
        assignments: {
          'x': {'a'},
          'y': {'b'},
        },
        charges: const ReceiptCharges(tax: 5.0, service: 4.0),
      );
      final sum = totals.perDiner
          .fold<int>(0, (a, t) => a + t.grandTotalCents);
      expect((sum - totals.billGrandTotalCents).abs(), lessThanOrEqualTo(2));
      expect(totals.billGrandTotalCents, 5900); // 50 + 5 + 4
    });

    test('unassigned item does not contribute to any diner', () {
      final totals = computeTotals(
        diners: [_d('a', 'A')],
        items: [_i('x', 'X', 10.0), _i('y', 'Y', 5.0)],
        assignments: {
          'x': {'a'},
        },
        charges: const ReceiptCharges(),
      );
      expect(totals.perDiner.single.subtotalCents, 1000);
    });

    test('unassignedItems returns items with no assignees', () {
      final result = unassignedItems(
        [_i('x', 'X', 10), _i('y', 'Y', 5)],
        {
          'x': {'a'},
        },
      );
      expect(result.map((i) => i.id), ['y']);
    });

    test('residual surfaces when proportional split yields fractions', () {
      // 3 diners equal share of 10 -> 3.33/3.33/3.34 sums to 10.00 exactly via
      // largest-remainder allocation, no residual on subtotal. With tax that
      // doesn't divide evenly, residual stays at 0 because allocation is
      // largest-remainder. We assert residual is small.
      final totals = computeTotals(
        diners: [_d('a', 'A'), _d('b', 'B'), _d('c', 'C')],
        items: [_i('x', 'X', 10.0)],
        assignments: {
          'x': {'a', 'b', 'c'},
        },
        charges: const ReceiptCharges(tax: 1.0),
      );
      expect(totals.roundingResidualCents.abs(), lessThanOrEqualTo(3));
      final sum = totals.perDiner
          .fold<int>(0, (a, t) => a + t.grandTotalCents);
      expect(sum + totals.roundingResidualCents, totals.billGrandTotalCents);
    });
  });
}
