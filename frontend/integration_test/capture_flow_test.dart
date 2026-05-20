// Capture-flow golden path: FR-001 + FR-003 + FR-004.
//
// Runs as a Flutter widget test (no real device required for this one). It
// composes PeopleScreen and UploadScreen with a shared in-memory bill state
// holder + mocked extract repository + mocked image picker, then drives the
// end-to-end golden path: add two people → upload (camera) → extracted items
// visible.
import 'dart:typed_data';

import 'package:bill_splitter/features/bill/data/extract_repository.dart';
import 'package:bill_splitter/features/bill/model/item.dart';
import 'package:bill_splitter/features/bill/model/person.dart';
import 'package:bill_splitter/features/bill/screens/people_screen.dart';
import 'package:bill_splitter/features/bill/screens/upload_screen.dart';
import 'package:bill_splitter/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements ExtractRepository {
  @override
  Future<ExtractResult> extract(Uint8List bytes) async {
    return ExtractResult(
      items: [
        Item.create(name: 'Koshary', quantity: 2, unitPrice: 55, source: ItemSource.extracted),
        Item.create(name: 'Cola', quantity: 1, unitPrice: 30, source: ItemSource.extracted),
      ],
      taxAmount: 20,
      serviceAmount: 17,
    );
  }
}

class _CaptureFlowHarness extends StatefulWidget {
  const _CaptureFlowHarness();
  @override
  State<_CaptureFlowHarness> createState() => _CaptureFlowHarnessState();
}

class _CaptureFlowHarnessState extends State<_CaptureFlowHarness> {
  List<Person>? _people;
  ExtractResult? _result;
  final _repo = _FakeRepo();

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return Scaffold(
        body: ListView(
          children: [
            for (final item in _result!.items)
              ListTile(
                key: Key('extracted-${item.name}'),
                title: Text(item.name),
                subtitle: Text('${item.quantity} × ${item.unitPrice}'),
              ),
            if (_result!.taxAmount != null)
              ListTile(key: const Key('extracted-tax'), title: Text('Tax: ${_result!.taxAmount}')),
            if (_result!.serviceAmount != null)
              ListTile(
                key: const Key('extracted-service'),
                title: Text('Service: ${_result!.serviceAmount}'),
              ),
          ],
        ),
      );
    }
    if (_people != null) {
      return UploadScreen(
        repository: _repo,
        pickImage: (_) async => Uint8List.fromList(List.filled(64, 9)),
        onSuccess: (r) => setState(() => _result = r),
        onFailure: (_) {},
      );
    }
    return PeopleScreen(onProceed: (p) => setState(() => _people = p));
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
      home: const _CaptureFlowHarness(),
    );

void main() {
  testWidgets('FR-001 + FR-003 + FR-004: capture flow golden path', (tester) async {
    await tester.pumpWidget(_wrap());

    // FR-001 — add two people.
    await tester.enterText(find.byType(TextField), 'Mo');
    await tester.tap(find.byKey(const Key('add-person-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Sara');
    await tester.tap(find.byKey(const Key('add-person-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('people-next-button')));
    await tester.pumpAndSettle();

    // FR-003 — pick from camera.
    await tester.tap(find.byKey(const Key('upload-camera')));
    await tester.pumpAndSettle();

    // FR-004 — items visible with tax and service.
    expect(find.byKey(const Key('extracted-Koshary')), findsOneWidget);
    expect(find.byKey(const Key('extracted-Cola')), findsOneWidget);
    expect(find.byKey(const Key('extracted-tax')), findsOneWidget);
    expect(find.byKey(const Key('extracted-service')), findsOneWidget);
  });

}
