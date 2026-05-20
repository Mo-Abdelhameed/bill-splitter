import 'package:bill_splitter/features/bill/model/assignment.dart';
import 'package:bill_splitter/features/bill/model/item.dart';
import 'package:bill_splitter/features/bill/model/person.dart';
import 'package:bill_splitter/features/bill/screens/totals_screen.dart';
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
      source: ItemSource.manual,
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
  testWidgets('FR-016: shows subtotal, tax share, service share, and final per person', (tester) async {
    // A's items total 200, B's 100. Tax 30, service 30.
    // Per FR-012: A gets 20 of each (200/300 * 30), B gets 10 of each.
    // Final: A = 200+20+20 = 240, B = 100+10+10 = 120 (both whole, no rounding).
    final people = [_p('A', 'Ali'), _p('B', 'Beth')];
    final items = [_i('i1', 'A item', 200), _i('i2', 'B item', 100)];
    final assignments = {
      'i1': Assignment(itemId: 'i1', personIds: {'A'}),
      'i2': Assignment(itemId: 'i2', personIds: {'B'}),
    };

    await tester.pumpWidget(_wrap(TotalsScreen(
      people: people,
      items: items,
      assignments: assignments,
      taxAmount: 30,
      serviceAmount: 30,
      onStartNewBill: () {},
    )));

    // Ali's row
    expect(find.byKey(const Key('subtotal-A')), findsOneWidget);
    expect(find.byKey(const Key('tax-share-A')), findsOneWidget);
    expect(find.byKey(const Key('service-share-A')), findsOneWidget);
    expect(find.byKey(const Key('final-A')), findsOneWidget);
    expect(find.text('240'), findsOneWidget);
    // Beth's final
    expect(find.text('120'), findsOneWidget);
  });

  testWidgets('FR-013: tax and service rows are hidden when amounts are null', (tester) async {
    final people = [_p('A', 'Ali')];
    final items = [_i('i1', 'Solo', 80)];
    final assignments = {
      'i1': Assignment(itemId: 'i1', personIds: {'A'}),
    };

    await tester.pumpWidget(_wrap(TotalsScreen(
      people: people,
      items: items,
      assignments: assignments,
      taxAmount: null,
      serviceAmount: null,
      onStartNewBill: () {},
    )));

    expect(find.byKey(const Key('subtotal-A')), findsOneWidget);
    expect(find.byKey(const Key('tax-share-A')), findsNothing);
    expect(find.byKey(const Key('service-share-A')), findsNothing);
    expect(find.byKey(const Key('final-A')), findsOneWidget);
    expect(find.text('80'), findsWidgets);
  });

  testWidgets('FR-015: per-person final totals are rounded UP to whole EGP', (tester) async {
    // 3 people share a 100 item equally → each owes 33.33, rounded up to 34.
    final people = [_p('A', 'A'), _p('B', 'B'), _p('C', 'C')];
    final items = [_i('i1', 'Pizza', 100)];
    final assignments = {
      'i1': Assignment(itemId: 'i1', personIds: {'A', 'B', 'C'}),
    };

    await tester.pumpWidget(_wrap(TotalsScreen(
      people: people,
      items: items,
      assignments: assignments,
      taxAmount: null,
      serviceAmount: null,
      onStartNewBill: () {},
    )));

    expect(find.text('34'), findsNWidgets(3));
  });

  testWidgets('FR-017: tapping Start new bill invokes the callback', (tester) async {
    var called = 0;
    await tester.pumpWidget(_wrap(TotalsScreen(
      people: [_p('A', 'A')],
      items: [_i('i1', 'X', 10)],
      assignments: {'i1': Assignment(itemId: 'i1', personIds: {'A'})},
      taxAmount: null,
      serviceAmount: null,
      onStartNewBill: () => called++,
    )));

    await tester.tap(find.byKey(const Key('start-new-bill-button')));
    await tester.pumpAndSettle();
    expect(called, 1);
  });
}
