import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bill_split/screens/totals_screen.dart';
import 'package:bill_split/state/bill_item.dart';
import 'package:bill_split/state/bill_state.dart';

/// Tests for TotalsScreen (T031). Totals are reported via stable per-person
/// keys so tests can read the rendered number without coupling to layout.
///
/// Money in EGP is rounded to 2 decimals (piastre). Floating-point residual
/// is surfaced on a dedicated "Rounding" line (user choice 2026-05-20).
void main() {
  group('TotalsScreen', () {
    /// Reads `Key('total-$name')` text and parses it as a double.
    double readTotal(WidgetTester tester, String name) {
      final txt = tester
          .widget<Text>(find.byKey(ValueKey<String>('total-$name')))
          .data!;
      return double.parse(txt);
    }

    Widget buildSubject(BillState s) => MaterialApp(home: TotalsScreen(billState: s));

    testWidgets(
      'FR-016: every person from the bill is rendered as a card with name + total',
      (tester) async {
        final s = BillState()
          ..people = <String>['Alice', 'Bob']
          ..items = <BillItem>[const BillItem(id: 'i1', name: 'pasta', price: 30)]
          ..assignments = <String, Map<String, double>>{
            'i1': <String, double>{'Alice': 1, 'Bob': 1},
          };

        await tester.pumpWidget(buildSubject(s));

        expect(find.byKey(const ValueKey<String>('person-card-Alice')),
            findsOneWidget);
        expect(find.byKey(const ValueKey<String>('person-card-Bob')),
            findsOneWidget);
        expect(find.byKey(const ValueKey<String>('total-Alice')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('total-Bob')), findsOneWidget);
      },
    );

    testWidgets(
      'FR-007: equal-split — a 30 EGP item among 3 people gives each exactly 10',
      (tester) async {
        final s = BillState()
          ..people = <String>['A', 'B', 'C']
          ..items = <BillItem>[const BillItem(id: 'i1', name: 'pizza', price: 30)]
          ..assignments = <String, Map<String, double>>{
            'i1': <String, double>{'A': 1, 'B': 1, 'C': 1},
          };

        await tester.pumpWidget(buildSubject(s));

        expect(readTotal(tester, 'A'), 10.00);
        expect(readTotal(tester, 'B'), 10.00);
        expect(readTotal(tester, 'C'), 10.00);
      },
    );

    testWidgets(
      'FR-007a: weighted 2:1 — a 30 EGP item split 2:1 gives 20 / 10',
      (tester) async {
        final s = BillState()
          ..people = <String>['Heavy', 'Light']
          ..items = <BillItem>[const BillItem(id: 'i1', name: 'wagyu', price: 30)]
          ..assignments = <String, Map<String, double>>{
            'i1': <String, double>{'Heavy': 2, 'Light': 1},
          };

        await tester.pumpWidget(buildSubject(s));

        expect(readTotal(tester, 'Heavy'), 20.00);
        expect(readTotal(tester, 'Light'), 10.00);
      },
    );

    testWidgets(
      'FR-009: tax marked included — per-person totals do NOT add tax on top',
      (tester) async {
        final s = BillState()
          ..people = <String>['Alice', 'Bob']
          ..items = <BillItem>[const BillItem(id: 'i1', name: 'pasta', price: 100)]
          ..assignments = <String, Map<String, double>>{
            'i1': <String, double>{'Alice': 1, 'Bob': 1},
          }
          ..tax = 14
          ..taxIncluded = true
          ..service = null;

        await tester.pumpWidget(buildSubject(s));

        // 100 / 2 = 50 each. Tax already in the price → no addition.
        expect(readTotal(tester, 'Alice'), 50.00);
        expect(readTotal(tester, 'Bob'), 50.00);
      },
    );

    testWidgets(
      'FR-010: tax marked not-included — per-person totals add proportional tax share',
      (tester) async {
        final s = BillState()
          ..people = <String>['Alice', 'Bob']
          ..items = <BillItem>[const BillItem(id: 'i1', name: 'pasta', price: 100)]
          ..assignments = <String, Map<String, double>>{
            'i1': <String, double>{'Alice': 1, 'Bob': 1},
          }
          ..tax = 14
          ..taxIncluded = false
          ..service = null;

        await tester.pumpWidget(buildSubject(s));

        // Each: items 50 + tax 7 = 57.
        expect(readTotal(tester, 'Alice'), 57.00);
        expect(readTotal(tester, 'Bob'), 57.00);
      },
    );

    testWidgets(
      'FR-009: service marked included — per-person totals do NOT add service on top',
      (tester) async {
        final s = BillState()
          ..people = <String>['Alice', 'Bob']
          ..items = <BillItem>[const BillItem(id: 'i1', name: 'pasta', price: 100)]
          ..assignments = <String, Map<String, double>>{
            'i1': <String, double>{'Alice': 1, 'Bob': 1},
          }
          ..service = 12
          ..serviceIncluded = true
          ..tax = null;

        await tester.pumpWidget(buildSubject(s));

        expect(readTotal(tester, 'Alice'), 50.00);
        expect(readTotal(tester, 'Bob'), 50.00);
      },
    );

    testWidgets(
      'FR-010: service marked not-included — per-person totals add proportional service share',
      (tester) async {
        final s = BillState()
          ..people = <String>['Alice', 'Bob']
          ..items = <BillItem>[const BillItem(id: 'i1', name: 'pasta', price: 100)]
          ..assignments = <String, Map<String, double>>{
            'i1': <String, double>{'Alice': 1, 'Bob': 1},
          }
          ..service = 12
          ..serviceIncluded = false
          ..tax = null;

        await tester.pumpWidget(buildSubject(s));

        expect(readTotal(tester, 'Alice'), 56.00);
        expect(readTotal(tester, 'Bob'), 56.00);
      },
    );

    testWidgets(
      'FR-008: sum of per-person totals equals the bill total (items + on-top tax + on-top service), modulo rounding residual',
      (tester) async {
        final s = BillState()
          ..people = <String>['Alice', 'Bob']
          ..items = <BillItem>[
            const BillItem(id: 'i1', name: 'pasta', price: 100),
            const BillItem(id: 'i2', name: 'salad', price: 50),
          ]
          ..assignments = <String, Map<String, double>>{
            'i1': <String, double>{'Alice': 1, 'Bob': 1},
            'i2': <String, double>{'Alice': 1},
          }
          ..tax = 14
          ..taxIncluded = false
          ..service = 12
          ..serviceIncluded = false;

        await tester.pumpWidget(buildSubject(s));

        final alice = readTotal(tester, 'Alice');
        final bob = readTotal(tester, 'Bob');

        // Read the displayed rounding residual (0.0 when not shown).
        double residual = 0;
        final residualFinder = find.byKey(const ValueKey<String>('rounding-residual'));
        if (residualFinder.evaluate().isNotEmpty) {
          residual = double.parse(
              tester.widget<Text>(residualFinder).data!.replaceAll(RegExp(r'[^0-9.\-]'), ''));
        }

        // Bill total = items 150 + tax 14 + service 12 = 176.
        expect(alice + bob + residual, closeTo(176.0, 0.0001));
      },
    );

    testWidgets(
      'FR-008: rounding residual is displayed (not silently distributed) — 100 EGP split 3 ways shows 0.01',
      (tester) async {
        final s = BillState()
          ..people = <String>['A', 'B', 'C']
          ..items = <BillItem>[const BillItem(id: 'i1', name: 'thing', price: 100)]
          ..assignments = <String, Map<String, double>>{
            'i1': <String, double>{'A': 1, 'B': 1, 'C': 1},
          };

        await tester.pumpWidget(buildSubject(s));

        // Each person displays 33.33; 3 * 33.33 = 99.99 → residual 0.01.
        expect(readTotal(tester, 'A'), 33.33);
        expect(readTotal(tester, 'B'), 33.33);
        expect(readTotal(tester, 'C'), 33.33);

        final residualFinder = find.byKey(const ValueKey<String>('rounding-residual'));
        expect(residualFinder, findsOneWidget,
            reason: 'a residual of 0.01 must be surfaced as its own line');
        final txt = tester.widget<Text>(residualFinder).data!;
        expect(txt.contains('0.01'), isTrue, reason: 'shown residual must read 0.01');
      },
    );
  });
}
