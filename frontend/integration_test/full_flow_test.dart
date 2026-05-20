// SC-001: a user completes a 4-person, 10-item bill end-to-end (add people →
// upload → assign → totals). The mocked repo returns 10 items with
// deterministic IDs so the test can target specific FilterChips by key.
import 'dart:typed_data';

import 'package:bill_splitter/features/bill/data/extract_repository.dart';
import 'package:bill_splitter/features/bill/model/assignment.dart';
import 'package:bill_splitter/features/bill/model/item.dart';
import 'package:bill_splitter/features/bill/model/person.dart';
import 'package:bill_splitter/features/bill/screens/assign_screen.dart';
import 'package:bill_splitter/features/bill/screens/people_screen.dart';
import 'package:bill_splitter/features/bill/screens/totals_screen.dart';
import 'package:bill_splitter/features/bill/screens/upload_screen.dart';
import 'package:bill_splitter/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Item _fixedItem(int i) => Item(
      id: 'i$i',
      name: 'Item$i',
      quantity: 1,
      unitPrice: 50,
      source: ItemSource.extracted,
    );

class _Repo implements ExtractRepository {
  @override
  Future<ExtractResult> extract(Uint8List bytes) async {
    return ExtractResult(
      items: [for (var i = 1; i <= 10; i++) _fixedItem(i)],
      taxAmount: 70,
      serviceAmount: 30,
    );
  }
}

class _Harness extends StatefulWidget {
  const _Harness();
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  // People with predictable IDs so chip keys are predictable.
  final List<Person> _fixedPeople = [
    Person(id: 'A', name: 'Ali'),
    Person(id: 'B', name: 'Beth'),
    Person(id: 'C', name: 'Cara'),
    Person(id: 'D', name: 'Dia'),
  ];

  bool _peopleDone = false;
  ExtractResult? _extracted;
  Map<String, Assignment>? _assignments;
  bool _newBillRequested = false;

  final _repo = _Repo();

  @override
  Widget build(BuildContext context) {
    if (_newBillRequested) {
      return const Scaffold(
        body: Center(child: Text('NEW BILL', key: Key('new-bill-marker'))),
      );
    }
    if (_assignments != null) {
      return TotalsScreen(
        people: _fixedPeople,
        items: _extracted!.items,
        assignments: _assignments!,
        taxAmount: _extracted!.taxAmount,
        serviceAmount: _extracted!.serviceAmount,
        onStartNewBill: () => setState(() => _newBillRequested = true),
      );
    }
    if (_extracted != null) {
      return AssignScreen(
        people: _fixedPeople,
        items: _extracted!.items,
        initialAssignments: const {},
        onProceed: (a) => setState(() => _assignments = a),
      );
    }
    if (_peopleDone) {
      return UploadScreen(
        repository: _repo,
        pickImage: (_) async => Uint8List.fromList(List.filled(8, 0)),
        onSuccess: (r) => setState(() => _extracted = r),
        onFailure: (_) {},
      );
    }
    // PeopleScreen for the user to add names (we ignore their list and use
    // _fixedPeople downstream so the chip keys stay predictable).
    return PeopleScreen(onProceed: (_) => setState(() => _peopleDone = true));
  }
}

Widget _wrap() => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _Harness(),
    );

Future<void> _addPerson(WidgetTester t, String name) async {
  await t.enterText(find.byType(TextField), name);
  await t.tap(find.byKey(const Key('add-person-button')));
  await t.pumpAndSettle();
}

Future<void> _tapChip(WidgetTester t, String itemId, String personId) async {
  final chip = find.byKey(Key('chip-$itemId-$personId'));
  await t.scrollUntilVisible(chip, 80);
  await t.tap(chip);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('FR-011 + FR-012 + FR-015: SC-001 4-person 10-item end-to-end', (tester) async {
    await tester.pumpWidget(_wrap());

    // Add 4 people on PeopleScreen.
    await _addPerson(tester, 'Ali');
    await _addPerson(tester, 'Beth');
    await _addPerson(tester, 'Cara');
    await _addPerson(tester, 'Dia');
    await tester.tap(find.byKey(const Key('people-next-button')));
    await tester.pumpAndSettle();

    // Upload via camera (mocked).
    await tester.tap(find.byKey(const Key('upload-camera')));
    await tester.pumpAndSettle();

    // Distribute 10 items 4-3-2-1.
    // A: 1..4, B: 5..7, C: 8..9, D: 10
    // Subtotals: A=200, B=150, C=100, D=50, total=500.
    // Tax 70 → A 28, B 21, C 14, D 7.
    // Service 30 → A 12, B 9, C 6, D 3.
    // Finals: A 240, B 180, C 120, D 60.
    const picks = [
      ['i1', 'A'], ['i2', 'A'], ['i3', 'A'], ['i4', 'A'],
      ['i5', 'B'], ['i6', 'B'], ['i7', 'B'],
      ['i8', 'C'], ['i9', 'C'],
      ['i10', 'D'],
    ];
    for (final p in picks) {
      await _tapChip(tester, p[0], p[1]);
    }

    await tester.tap(find.byKey(const Key('assign-view-totals')));
    await tester.pumpAndSettle();

    // Finals.
    expect(find.text('240'), findsOneWidget);
    expect(find.text('180'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('60'), findsOneWidget);

    // FR-017: Start new bill.
    await tester.tap(find.byKey(const Key('start-new-bill-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('new-bill-marker')), findsOneWidget);
  });
}
