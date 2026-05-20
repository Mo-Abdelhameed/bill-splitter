import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bill_split/screens/extraction_screen.dart';
import 'package:bill_split/services/extraction_client.dart';
import 'package:bill_split/state/bill_item.dart';
import 'package:bill_split/state/bill_state.dart';

/// Hand-written fake — configurable per test, no mocking library.
class FakeExtractionClient implements ExtractionClient {
  ExtractionResult? successResult;
  Object? errorToThrow;
  Future<ExtractionResult>? customFuture;
  int callCount = 0;
  Uint8List? lastImageBytes;

  @override
  Future<ExtractionResult> extract(Uint8List imageBytes) {
    callCount++;
    lastImageBytes = imageBytes;
    if (customFuture != null) return customFuture!;
    if (errorToThrow != null) return Future<ExtractionResult>.error(errorToThrow!);
    return Future<ExtractionResult>.value(
      successResult ?? const ExtractionResult.empty(),
    );
  }
}

void main() {
  group('ExtractionScreen', () {
    late BillState billState;
    late FakeExtractionClient fake;
    late bool continueCalled;

    final sampleImage = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);

    setUp(() {
      billState = BillState()..imageBytes = sampleImage;
      fake = FakeExtractionClient();
      continueCalled = false;
    });

    Widget buildSubject() => MaterialApp(
          home: ExtractionScreen(
            billState: billState,
            extractor: fake,
            onContinue: () => continueCalled = true,
          ),
        );

    Finder findContinueButton() => find.ancestor(
          of: find.text('Continue'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        );

    bool continueEnabled(WidgetTester tester) {
      final widget = tester.widget<ButtonStyleButton>(findContinueButton());
      return widget.onPressed != null;
    }

    // Drive a successful extraction with the given items+tax+service. Leaves
    // the screen in the editable state.
    Future<void> doSuccessfulExtraction(
      WidgetTester tester, {
      required List<BillItem> items,
      double? tax,
      double? service,
    }) async {
      fake.successResult = ExtractionResult(
        items: items,
        tax: tax,
        service: service,
      );
      await tester.tap(find.text('Extract items'));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'FR-002: initial state shows image preview, "Extract items" button, no items list, and no extractor call yet',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Extract items'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
      expect(fake.callCount, 0);
    });

    testWidgets(
        'FR-002: tap Extract triggers exactly one backend call with the image bytes and transitions to a loading state',
        (tester) async {
      final completer = Completer<ExtractionResult>();
      fake.customFuture = completer.future;

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('Extract items'));
      await tester.pump(); // begin the async call

      expect(fake.callCount, 1);
      expect(fake.lastImageBytes, equals(sampleImage));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Resolve so the test cleans up.
      completer.complete(const ExtractionResult(
        items: <BillItem>[BillItem(name: 'x', price: 1)],
        tax: null,
        service: null,
      ));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
        'FR-003: successful response renders the editable items list',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await doSuccessfulExtraction(
        tester,
        items: <BillItem>[
          const BillItem(name: 'pasta', price: 50),
          const BillItem(name: 'pasta', price: 50),
          const BillItem(name: 'salad', price: 30),
        ],
      );

      expect(find.text('pasta'), findsNWidgets(2));
      expect(find.text('salad'), findsOneWidget);
      // 3 items × 2 fields each (name + price) = 6 text fields.
      expect(find.byType(TextField), findsNWidgets(6));
    });

    testWidgets(
        'FR-012: editing a row name or price updates in-screen state immediately',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await doSuccessfulExtraction(
        tester,
        items: <BillItem>[const BillItem(name: 'pasta', price: 50)],
      );

      await tester.enterText(find.byType(TextField).at(0), 'spaghetti');
      await tester.pump();
      expect(find.text('spaghetti'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(1), '60');
      await tester.pump();
      expect(find.text('60'), findsOneWidget);
    });

    testWidgets(
        'FR-014: deleting a row via the per-row delete affordance removes it from the screen',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await doSuccessfulExtraction(
        tester,
        items: <BillItem>[
          const BillItem(name: 'pasta', price: 50),
          const BillItem(name: 'salad', price: 30),
        ],
      );

      expect(find.text('pasta'), findsOneWidget);
      expect(find.text('salad'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete).first);
      await tester.pumpAndSettle();

      expect(find.text('pasta'), findsNothing);
      expect(find.text('salad'), findsOneWidget);
    });

    testWidgets(
        'FR-013: tapping Add item appends a new empty row with name "" and price 0',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await doSuccessfulExtraction(
        tester,
        items: <BillItem>[const BillItem(name: 'pasta', price: 50)],
      );

      expect(find.byType(TextField), findsNWidgets(2));

      await tester.tap(find.text('Add item'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(4));
      final fields =
          tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields[2].controller?.text ?? '', isEmpty);
      expect(fields[3].controller?.text, '0');
    });

    testWidgets(
        'FR-004: tax non-null shows checked Tax checkbox with editable amount',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await doSuccessfulExtraction(
        tester,
        items: <BillItem>[const BillItem(name: 'x', price: 10)],
        tax: 14.0,
      );

      final taxBox = tester.widget<Checkbox>(
        find.byKey(const ValueKey<String>('tax-checkbox')),
      );
      expect(taxBox.value, isTrue);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('tax-amount-field')),
          matching: find.text('14.0'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'FR-004: tax null shows unchecked Tax checkbox, no amount input',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await doSuccessfulExtraction(
        tester,
        items: <BillItem>[const BillItem(name: 'x', price: 10)],
      );

      final taxBox = tester.widget<Checkbox>(
        find.byKey(const ValueKey<String>('tax-checkbox')),
      );
      expect(taxBox.value, isFalse);
      expect(
        find.byKey(const ValueKey<String>('tax-amount-field')),
        findsNothing,
      );
    });

    testWidgets(
        'FR-004: service non-null shows checked Service checkbox with editable amount',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await doSuccessfulExtraction(
        tester,
        items: <BillItem>[const BillItem(name: 'x', price: 10)],
        service: 12.0,
      );

      final svcBox = tester.widget<Checkbox>(
        find.byKey(const ValueKey<String>('service-checkbox')),
      );
      expect(svcBox.value, isTrue);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('service-amount-field')),
          matching: find.text('12.0'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'FR-004: service null shows unchecked Service checkbox, no amount input',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await doSuccessfulExtraction(
        tester,
        items: <BillItem>[const BillItem(name: 'x', price: 10)],
      );

      final svcBox = tester.widget<Checkbox>(
        find.byKey(const ValueKey<String>('service-checkbox')),
      );
      expect(svcBox.value, isFalse);
      expect(
        find.byKey(const ValueKey<String>('service-amount-field')),
        findsNothing,
      );
    });

    testWidgets(
        'FR-004: unchecking a checked checkbox removes the amount input and nulls in-screen state',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await doSuccessfulExtraction(
        tester,
        items: <BillItem>[const BillItem(name: 'x', price: 10)],
        tax: 14.0,
        service: 12.0,
      );

      await tester.tap(find.byKey(const ValueKey<String>('tax-checkbox')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('tax-amount-field')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey<String>('service-checkbox')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('service-amount-field')),
        findsNothing,
      );

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(billState.tax, isNull);
      expect(billState.service, isNull);
    });

    testWidgets(
        'FR-004: checking an unchecked checkbox shows amount input defaulting to 0',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await doSuccessfulExtraction(
        tester,
        items: <BillItem>[const BillItem(name: 'x', price: 10)],
      );

      await tester.tap(find.byKey(const ValueKey<String>('tax-checkbox')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('tax-amount-field')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('tax-amount-field')),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('service-checkbox')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('service-amount-field')),
        findsOneWidget,
      );
    });

    testWidgets(
        'FR-015: extraction failure shows error + Retry + manual-fallback; Retry re-issues; manual fallback enters empty editable state',
        (tester) async {
      fake.errorToThrow = ExtractionException(ExtractionFailure.network);

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('Extract items'));
      await tester.pumpAndSettle();

      expect(find.textContaining('network', findRichText: true),
          findsAtLeastNWidgets(1));
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Enter items manually'), findsOneWidget);

      // Configure for success on retry.
      fake.errorToThrow = null;
      fake.successResult = const ExtractionResult(
        items: <BillItem>[BillItem(name: 'after-retry', price: 1)],
        tax: null,
        service: null,
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(fake.callCount, 2);
      expect(fake.lastImageBytes, equals(sampleImage));
      expect(find.text('after-retry'), findsOneWidget);

      // Reset and test manual-fallback path on a fresh failure.
      billState = BillState()..imageBytes = sampleImage;
      fake = FakeExtractionClient()
        ..errorToThrow = ExtractionException(ExtractionFailure.network);
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('Extract items'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enter items manually'));
      await tester.pumpAndSettle();

      expect(find.text('Add item'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      final taxBox = tester.widget<Checkbox>(
        find.byKey(const ValueKey<String>('tax-checkbox')),
      );
      final svcBox = tester.widget<Checkbox>(
        find.byKey(const ValueKey<String>('service-checkbox')),
      );
      expect(taxBox.value, isFalse);
      expect(svcBox.value, isFalse);
    });

    testWidgets(
        'FR-016: Continue is enabled iff items list contains >=1 trimmed non-empty name',
        (tester) async {
      // First: with one named item → enabled.
      await tester.pumpWidget(buildSubject());
      await doSuccessfulExtraction(
        tester,
        items: <BillItem>[const BillItem(name: 'pasta', price: 50)],
      );
      expect(continueEnabled(tester), isTrue);

      // Reset; empty list → disabled; whitespace-only name → disabled.
      billState = BillState()..imageBytes = sampleImage;
      fake = FakeExtractionClient()
        ..errorToThrow = ExtractionException(ExtractionFailure.network);
      continueCalled = false;
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('Extract items'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enter items manually'));
      await tester.pumpAndSettle();

      expect(continueEnabled(tester), isFalse);

      await tester.tap(find.text('Add item'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '   ');
      await tester.pumpAndSettle();
      expect(continueEnabled(tester), isFalse);
    });

    testWidgets(
        'FR-008: tapping Continue commits items/tax/service to bill state and triggers navigation',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await doSuccessfulExtraction(
        tester,
        items: <BillItem>[
          const BillItem(name: '  pasta  ', price: 50),
          const BillItem(name: 'salad', price: 30),
        ],
        tax: 14.0,
        service: 12.0,
      );

      expect(continueEnabled(tester), isTrue);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(billState.items.length, 2);
      expect(billState.items[0].name, 'pasta');
      expect(billState.items[0].price, 50);
      expect(billState.items[1].name, 'salad');
      expect(billState.items[1].price, 30);
      expect(billState.tax, 14.0);
      expect(billState.service, 12.0);
      // Segmented control defaults to "Added on top" — Constitution
      // FR-010 path. billState.taxIncluded / serviceIncluded should be
      // false so the Totals screen adds them to each person's share.
      expect(billState.taxIncluded, isFalse);
      expect(billState.serviceIncluded, isFalse);

      expect(continueCalled, isTrue);
    });

    testWidgets(
        'FR-009/FR-010: tapping "Included in items" on the Tax segmented control sets billState.taxIncluded=true on Continue',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await doSuccessfulExtraction(
        tester,
        items: <BillItem>[const BillItem(name: 'pasta', price: 100)],
        tax: 14.0,
      );

      // Default is "Added on top" → taxIncluded=false. Flip to "Included
      // in items" via the segmented control under the Tax row.
      final segment = find.descendant(
        of: find.byKey(const ValueKey<String>('tax-segment')),
        matching: find.text('Included in items'),
      );
      expect(segment, findsOneWidget);
      await tester.tap(segment);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(billState.tax, 14.0);
      expect(billState.taxIncluded, isTrue);
    });

    testWidgets(
        'FR-009/FR-010: Service segmented control flips serviceIncluded independently of tax',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await doSuccessfulExtraction(
        tester,
        items: <BillItem>[const BillItem(name: 'pasta', price: 100)],
        tax: 14.0,
        service: 12.0,
      );

      // Flip Service to "Included in items" but leave Tax on "Added on top".
      // The service charge row sits below the tax row — scroll it into view
      // before the tap so hit-testing doesn't miss.
      final svcIncluded = find.descendant(
        of: find.byKey(const ValueKey<String>('service-segment')),
        matching: find.text('Included in items'),
      );
      expect(svcIncluded, findsOneWidget);
      await tester.ensureVisible(svcIncluded);
      await tester.pumpAndSettle();
      await tester.tap(svcIncluded);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(billState.taxIncluded, isFalse);
      expect(billState.serviceIncluded, isTrue);
    });

    testWidgets(
        'FR-002: 401 from backend maps to ExtractionFailure.unauthorized and surfaces a re-auth prompt',
        (tester) async {
      fake.errorToThrow = ExtractionException(
        ExtractionFailure.unauthorized,
        'token expired',
      );

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('Extract items'));
      await tester.pumpAndSettle();

      // Re-auth prompt visible (text references signing in again) and the
      // raw enum-name "unauthorized" headline is NOT shown.
      expect(
        find.textContaining('sign in again', findRichText: true),
        findsAtLeastNWidgets(1),
      );
      expect(find.text('Extraction failed: unauthorized'), findsNothing);

      // Retry + manual-fallback still offered.
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Enter items manually'), findsOneWidget);
    });
  });
}
