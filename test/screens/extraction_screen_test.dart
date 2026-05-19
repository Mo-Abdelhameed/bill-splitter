import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bill_split/screens/extraction_screen.dart';
import 'package:bill_split/services/gemini_extractor.dart';
import 'package:bill_split/state/bill_item.dart';
import 'package:bill_split/state/bill_state.dart';

/// Hand-written fake extractor — configurable per test, no mocking library.
class FakeGeminiExtractor implements GeminiExtractor {
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
    late FakeGeminiExtractor fake;
    late bool continueCalled;

    final sampleImage = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);

    setUp(() {
      billState = BillState()..imageBytes = sampleImage;
      fake = FakeGeminiExtractor();
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
        'STORY-002 AC-1: initial render shows image preview, Extract items button, no items list, and no Gemini call yet',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Extract items'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
      expect(fake.callCount, 0);
    });

    testWidgets(
        'STORY-002 AC-2: tapping Extract items issues exactly one call with the image bytes and transitions to a loading state',
        (tester) async {
      final completer = Completer<ExtractionResult>();
      fake.customFuture = completer.future;

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('Extract items'));
      await tester.pump(); // begin the async call

      expect(fake.callCount, 1);
      expect(fake.lastImageBytes, equals(sampleImage));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Resolve the future so the test cleans up.
      completer.complete(const ExtractionResult(
        items: <BillItem>[BillItem(name: 'x', price: 1)],
        tax: null,
        service: null,
      ));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
        'STORY-002 AC-4: successful response renders the items list with editable name and price for each entry',
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
        'STORY-002 AC-5: editing a row name or price updates in-screen state immediately',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await doSuccessfulExtraction(
        tester,
        items: <BillItem>[const BillItem(name: 'pasta', price: 50)],
      );

      // Edit name.
      await tester.enterText(find.byType(TextField).at(0), 'spaghetti');
      await tester.pump();
      expect(find.text('spaghetti'), findsOneWidget);

      // Edit price.
      await tester.enterText(find.byType(TextField).at(1), '60');
      await tester.pump();
      expect(find.text('60'), findsOneWidget);
    });

    testWidgets(
        'STORY-002 AC-6: deleting a row via the per-row delete affordance removes it from the screen',
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

      // Tap delete next to first row.
      await tester.tap(find.byIcon(Icons.delete).first);
      await tester.pumpAndSettle();

      expect(find.text('pasta'), findsNothing);
      expect(find.text('salad'), findsOneWidget);
    });

    testWidgets(
        'STORY-002 AC-7: tapping Add item appends a new empty row with name "" and price 0',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await doSuccessfulExtraction(
        tester,
        items: <BillItem>[const BillItem(name: 'pasta', price: 50)],
      );

      expect(find.byType(TextField), findsNWidgets(2));

      await tester.tap(find.text('Add item'));
      await tester.pumpAndSettle();

      // 2 rows now → 4 text fields.
      expect(find.byType(TextField), findsNWidgets(4));
      // New row has empty name and zero price.
      final priceFields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      // The newest fields are last in the list.
      expect(priceFields[2].controller?.text ?? '', isEmpty);
      expect(priceFields[3].controller?.text, '0');
    });

    testWidgets(
        'STORY-002 AC-8: response with non-null tax shows checked Tax checkbox and editable tax amount',
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
      // Tax input shows the value.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('tax-amount-field')),
          matching: find.text('14.0'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'STORY-002 AC-9: response with null tax shows unchecked Tax checkbox and no tax amount input',
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
        'STORY-002 AC-10: response with non-null service shows checked Service checkbox and editable service amount',
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
        'STORY-002 AC-11: response with null service shows unchecked Service checkbox and no service amount input',
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
        'STORY-002 AC-12: unchecking a checked Tax (or Service) checkbox removes the amount input and nulls the value',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await doSuccessfulExtraction(
        tester,
        items: <BillItem>[const BillItem(name: 'x', price: 10)],
        tax: 14.0,
        service: 12.0,
      );

      // Uncheck tax.
      await tester.tap(find.byKey(const ValueKey<String>('tax-checkbox')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('tax-amount-field')),
        findsNothing,
      );

      // Uncheck service.
      await tester.tap(find.byKey(const ValueKey<String>('service-checkbox')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('service-amount-field')),
        findsNothing,
      );

      // Continue should commit nulls.
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(billState.tax, isNull);
      expect(billState.service, isNull);
    });

    testWidgets(
        'STORY-002 AC-13: checking an unchecked Tax (or Service) box shows an amount input defaulting to 0',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await doSuccessfulExtraction(
        tester,
        items: <BillItem>[const BillItem(name: 'x', price: 10)],
      );

      // Both initially unchecked (tax and service are null).
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
        'STORY-002 AC-14: extraction failure shows an error message, a Retry button, and a manual-fallback button; Retry re-issues the call; Manual fallback enters empty editable state',
        (tester) async {
      // First call fails.
      fake.errorToThrow = ExtractionException(ExtractionFailure.network);

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('Extract items'));
      await tester.pumpAndSettle();

      // Error UI present.
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

      // Reset and test manual fallback path on a fresh failure.
      billState = BillState()..imageBytes = sampleImage;
      fake = FakeGeminiExtractor()
        ..errorToThrow = ExtractionException(ExtractionFailure.network);
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('Extract items'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enter items manually'));
      await tester.pumpAndSettle();

      // Now in empty editable state: Add item present, no items rendered, tax/service unchecked.
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
        'STORY-002 AC-15: Continue is enabled when at least one item has a non-empty trimmed name',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await doSuccessfulExtraction(
        tester,
        items: <BillItem>[const BillItem(name: 'pasta', price: 50)],
      );

      expect(continueEnabled(tester), isTrue);
    });

    testWidgets(
        'STORY-002 AC-16: Continue is disabled when the items list is empty or all names are empty/whitespace-only',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      // Manual fallback gives us an empty list.
      fake.errorToThrow = ExtractionException(ExtractionFailure.network);
      await tester.tap(find.text('Extract items'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enter items manually'));
      await tester.pumpAndSettle();

      // Empty list → disabled.
      expect(continueEnabled(tester), isFalse);

      // Add an item but with whitespace-only name → still disabled.
      await tester.tap(find.text('Add item'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '   ');
      await tester.pumpAndSettle();
      expect(continueEnabled(tester), isFalse);
    });

    testWidgets(
        'STORY-002 AC-17: tapping Continue commits items/tax/service to bill state and triggers navigation',
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

      // Names trimmed, in order, in bill state.
      expect(billState.items.length, 2);
      expect(billState.items[0].name, 'pasta');
      expect(billState.items[0].price, 50);
      expect(billState.items[1].name, 'salad');
      expect(billState.items[1].price, 30);
      expect(billState.tax, 14.0);
      expect(billState.service, 12.0);

      expect(continueCalled, isTrue);
    });
  });
}
