import 'package:bill_splitter/features/bill/model/item.dart';
import 'package:bill_splitter/features/bill/screens/items_screen.dart';
import 'package:bill_splitter/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Item _i(String id, String name, num price, {int qty = 1}) => Item(
      id: id,
      name: name,
      quantity: qty,
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
  testWidgets('FR-006: editing an item name propagates to the proceed payload', (tester) async {
    ItemsScreenResult? captured;
    final initial = [_i('i1', 'Koshery', 50), _i('i2', 'Cola', 30)];

    await tester.pumpWidget(_wrap(ItemsScreen(
      initialItems: initial,
      initialTaxAmount: 10,
      initialServiceAmount: 5,
      onProceed: (r) => captured = r,
    )));

    await tester.enterText(find.byKey(const Key('item-name-i1')), 'Koshary');
    await tester.tap(find.byKey(const Key('items-next-button')));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.items.firstWhere((it) => it.id == 'i1').name, 'Koshary');
    expect(captured!.items.firstWhere((it) => it.id == 'i2').name, 'Cola');
  });

  testWidgets('FR-006: editing an item price propagates', (tester) async {
    ItemsScreenResult? captured;
    final initial = [_i('i1', 'Koshary', 50)];

    await tester.pumpWidget(_wrap(ItemsScreen(
      initialItems: initial,
      initialTaxAmount: null,
      initialServiceAmount: null,
      onProceed: (r) => captured = r,
    )));

    await tester.enterText(find.byKey(const Key('item-price-i1')), '75');
    await tester.tap(find.byKey(const Key('items-next-button')));
    await tester.pumpAndSettle();

    expect(captured!.items[0].unitPrice, 75);
  });

  testWidgets('FR-006: adding a new item produces a fresh manual-source row', (tester) async {
    ItemsScreenResult? captured;
    final initial = [_i('i1', 'Koshary', 50)];

    await tester.pumpWidget(_wrap(ItemsScreen(
      initialItems: initial,
      initialTaxAmount: null,
      initialServiceAmount: null,
      onProceed: (r) => captured = r,
    )));

    await tester.tap(find.byKey(const Key('items-add-button')));
    await tester.pumpAndSettle();

    // Brand-new row appears with index 1 (after the initial item).
    final newIndex = initial.length;
    await tester.enterText(find.byKey(Key('item-name-new-$newIndex')), 'Bread');
    await tester.enterText(find.byKey(Key('item-price-new-$newIndex')), '15');

    await tester.tap(find.byKey(const Key('items-next-button')));
    await tester.pumpAndSettle();

    expect(captured!.items, hasLength(2));
    final added = captured!.items.firstWhere((it) => it.name == 'Bread');
    expect(added.unitPrice, 15);
    expect(added.source, ItemSource.manual);
  });

  testWidgets('FR-006: deleting an item drops it from the proceed payload', (tester) async {
    ItemsScreenResult? captured;
    final initial = [_i('i1', 'Koshary', 50), _i('i2', 'Cola', 30)];

    await tester.pumpWidget(_wrap(ItemsScreen(
      initialItems: initial,
      initialTaxAmount: null,
      initialServiceAmount: null,
      onProceed: (r) => captured = r,
    )));

    await tester.tap(find.byKey(const Key('item-delete-i2')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('items-next-button')));
    await tester.pumpAndSettle();

    expect(captured!.items, hasLength(1));
    expect(captured!.items[0].id, 'i1');
  });

  testWidgets('FR-014: when extractor returned no tax/service, pre-fill 12% service & 14% tax of items subtotal',
      (tester) async {
    ItemsScreenResult? captured;
    final initial = [_i('i1', 'A', 100), _i('i2', 'B', 100)]; // subtotal 200

    await tester.pumpWidget(_wrap(ItemsScreen(
      initialItems: initial,
      initialTaxAmount: null,
      initialServiceAmount: null,
      onProceed: (r) => captured = r,
    )));

    // Without touching the tax/service fields, the pre-filled defaults are
    // submitted as-is.
    await tester.tap(find.byKey(const Key('items-next-button')));
    await tester.pumpAndSettle();

    expect(captured!.taxAmount, 28);     // 14% of 200
    expect(captured!.serviceAmount, 24); // 12% of 200
  });

  testWidgets('FR-014: extracted tax/service are pre-filled and editable', (tester) async {
    ItemsScreenResult? captured;
    final initial = [_i('i1', 'A', 100)];

    await tester.pumpWidget(_wrap(ItemsScreen(
      initialItems: initial,
      initialTaxAmount: 17,
      initialServiceAmount: 12,
      onProceed: (r) => captured = r,
    )));

    await tester.enterText(find.byKey(const Key('items-tax-field')), '20');
    await tester.tap(find.byKey(const Key('items-next-button')));
    await tester.pumpAndSettle();

    expect(captured!.taxAmount, 20);     // user overrode
    expect(captured!.serviceAmount, 12); // unchanged from pre-fill
  });

  testWidgets('FR-014: clearing tax field yields null in the result', (tester) async {
    ItemsScreenResult? captured;
    final initial = [_i('i1', 'A', 100)];

    await tester.pumpWidget(_wrap(ItemsScreen(
      initialItems: initial,
      initialTaxAmount: 17,
      initialServiceAmount: 12,
      onProceed: (r) => captured = r,
    )));

    await tester.enterText(find.byKey(const Key('items-tax-field')), '');
    await tester.tap(find.byKey(const Key('items-next-button')));
    await tester.pumpAndSettle();

    expect(captured!.taxAmount, isNull);
    expect(captured!.serviceAmount, 12);
  });
}
