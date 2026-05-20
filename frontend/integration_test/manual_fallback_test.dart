// FR-007 + SC-005: extraction failure → manual entry surface within 10s,
// end-to-end through PeopleScreen → UploadScreen → AssignScreen → TotalsScreen.
import 'dart:typed_data';

import 'package:bill_splitter/core/errors.dart';
import 'package:bill_splitter/features/bill/data/extract_repository.dart';
import 'package:bill_splitter/features/bill/model/assignment.dart';
import 'package:bill_splitter/features/bill/model/person.dart';
import 'package:bill_splitter/features/bill/screens/assign_screen.dart';
import 'package:bill_splitter/features/bill/screens/people_screen.dart';
import 'package:bill_splitter/features/bill/screens/totals_screen.dart';
import 'package:bill_splitter/features/bill/screens/upload_screen.dart';
import 'package:bill_splitter/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingRepo implements ExtractRepository {
  @override
  Future<ExtractResult> extract(Uint8List bytes) async {
    throw NetworkError('offline');
  }
}

class _Harness extends StatefulWidget {
  const _Harness();
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final List<Person> _people = [
    Person(id: 'A', name: 'Ali'),
    Person(id: 'B', name: 'Beth'),
  ];

  bool _peopleDone = false;
  ExtractResult? _items;
  Map<String, Assignment>? _assignments;

  @override
  Widget build(BuildContext context) {
    if (_assignments != null) {
      return TotalsScreen(
        people: _people,
        items: _items!.items,
        assignments: _assignments!,
        taxAmount: _items!.taxAmount,
        serviceAmount: _items!.serviceAmount,
        onStartNewBill: () {},
      );
    }
    if (_items != null) {
      return AssignScreen(
        people: _people,
        items: _items!.items,
        initialAssignments: const {},
        onProceed: (a) => setState(() => _assignments = a),
      );
    }
    if (_peopleDone) {
      return UploadScreen(
        repository: _FailingRepo(),
        pickImage: (_) async => Uint8List.fromList([1]),
        onSuccess: (r) => setState(() => _items = r),
        onFailure: (_) {},
      );
    }
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

void main() {
  testWidgets('FR-007 + SC-005: extraction failure → manual entry → end-to-end totals',
      (tester) async {
    final stopwatch = Stopwatch()..start();
    await tester.pumpWidget(_wrap());

    await _addPerson(tester, 'Ali');
    await _addPerson(tester, 'Beth');
    await tester.tap(find.byKey(const Key('people-next-button')));
    await tester.pumpAndSettle();

    // Tap camera → repo throws → manual-entry surface appears.
    await tester.tap(find.byKey(const Key('upload-camera')));
    await tester.pumpAndSettle();

    final timeToManual = stopwatch.elapsed;
    expect(find.byKey(const Key('manual-entry-surface')), findsOneWidget);
    // SC-005: within 10 seconds.
    expect(timeToManual.inSeconds, lessThan(10));

    // Type one item.
    await tester.enterText(find.byKey(const Key('manual-item-name-0')), 'Shawarma');
    await tester.enterText(find.byKey(const Key('manual-item-price-0')), '60');
    await tester.tap(find.byKey(const Key('manual-done-button')));
    await tester.pumpAndSettle();

    // AssignScreen: assign the lone item to both Ali and Beth.
    final chips = find.byWidgetPredicate(
      (w) => w is FilterChip,
    );
    expect(chips, findsNWidgets(2));
    await tester.tap(chips.at(0));
    await tester.pumpAndSettle();
    await tester.tap(chips.at(1));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('assign-view-totals')));
    await tester.pumpAndSettle();

    // 60 split equally → 30 each (rounded up — already whole).
    // Each person row renders "30" twice: subtotal and final.
    expect(find.byKey(const Key('final-A')), findsOneWidget);
    expect(find.byKey(const Key('final-B')), findsOneWidget);
    expect(find.text('30'), findsNWidgets(4));
  });
}
