import 'package:bill_splitter/features/bill/model/assignment.dart';
import 'package:bill_splitter/features/bill/model/item.dart';
import 'package:bill_splitter/features/bill/model/person.dart';
import 'package:bill_splitter/features/bill/screens/assign_screen.dart';
import 'package:bill_splitter/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Person _p(String id, String name) => Person(id: id, name: name);
Item _i(String id, String name, num price) => Item(
      id: id,
      name: name,
      quantity: 1,
      unitPrice: price,
      source: ItemSource.extracted,
    );

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

void main() {
  testWidgets('FR-008: tapping a person chip toggles assignment for that item',
      (tester) async {
    final people = [_p('A', 'Ali'), _p('B', 'Beth')];
    final items = [_i('i1', 'Koshary', 60)];
    Map<String, Assignment>? captured;

    await tester.pumpWidget(_wrap(AssignScreen(
      people: people,
      items: items,
      initialAssignments: const {},
      onProceed: (a) => captured = a,
    )));

    // Tap person A's chip on item i1 → assigns A.
    await tester.tap(find.byKey(const Key('chip-i1-A')));
    await tester.pumpAndSettle();
    // Tap person B's chip on item i1 → both assigned now.
    await tester.tap(find.byKey(const Key('chip-i1-B')));
    await tester.pumpAndSettle();

    // FR-010 blocker satisfied (i1 assigned), so View Totals enabled.
    await tester.tap(find.byKey(const Key('assign-view-totals')));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!['i1']!.personIds, {'A', 'B'});

    // Tap A again → toggles A off, leaving B only.
  });

  testWidgets('FR-010: View Totals is blocked while any item is unassigned',
      (tester) async {
    final people = [_p('A', 'Ali'), _p('B', 'Beth')];
    final items = [_i('i1', 'Cola', 30), _i('i2', 'Bread', 10)];
    var proceedCalls = 0;

    await tester.pumpWidget(_wrap(AssignScreen(
      people: people,
      items: items,
      initialAssignments: const {},
      onProceed: (_) => proceedCalls++,
    )));

    // Assign only i1 (i2 still unassigned).
    await tester.tap(find.byKey(const Key('chip-i1-A')));
    await tester.pumpAndSettle();

    // Button should be disabled — onProceed must not fire.
    await tester.tap(find.byKey(const Key('assign-view-totals')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(proceedCalls, 0);

    // Blocker hint should call out the unassigned item.
    expect(find.textContaining('Bread'), findsWidgets);

    // Once i2 is assigned, proceed becomes possible.
    await tester.tap(find.byKey(const Key('chip-i2-B')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assign-view-totals')));
    await tester.pumpAndSettle();
    expect(proceedCalls, 1);
  });

  testWidgets('FR-009: per-item weight override is captured in the assignment',
      (tester) async {
    final people = [_p('A', 'Ali'), _p('B', 'Beth')];
    final items = [_i('i1', 'Steak', 100)];
    Map<String, Assignment>? captured;

    await tester.pumpWidget(_wrap(AssignScreen(
      people: people,
      items: items,
      initialAssignments: const {},
      onProceed: (a) => captured = a,
    )));

    await tester.tap(find.byKey(const Key('chip-i1-A')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chip-i1-B')));
    await tester.pumpAndSettle();

    // Open the weight-override sheet for i1.
    await tester.tap(find.byKey(const Key('override-i1')));
    await tester.pumpAndSettle();

    // Set A=3, B=1.
    await tester.enterText(find.byKey(const Key('weight-i1-A')), '3');
    await tester.enterText(find.byKey(const Key('weight-i1-B')), '1');
    await tester.tap(find.byKey(const Key('weight-save-i1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('assign-view-totals')));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    final a = captured!['i1']!;
    expect(a.personIds, {'A', 'B'});
    expect(a.weights, isNotNull);
    expect(a.weights!['A'], 3);
    expect(a.weights!['B'], 1);
  });
}
