import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bill_split/screens/people_screen.dart';
import 'package:bill_split/state/bill_state.dart';

void main() {
  group('PeopleScreen', () {
    late BillState billState;
    late bool continueCalled;

    setUp(() {
      billState = BillState();
      continueCalled = false;
    });

    Widget buildSubject() {
      return MaterialApp(
        home: PeopleScreen(
          billState: billState,
          onContinue: () => continueCalled = true,
        ),
      );
    }

    Finder findContinueButton() => find.ancestor(
          of: find.text('Continue'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        );

    bool continueEnabled(WidgetTester tester) {
      final widget = tester.widget<ButtonStyleButton>(findContinueButton());
      return widget.onPressed != null;
    }

    testWidgets(
        'STORY-001 AC-1: initial render shows exactly one empty name field, Add another with + icon, and disabled Continue',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(TextField), findsOneWidget);
      final initialField = tester.widget<TextField>(find.byType(TextField));
      expect(initialField.controller?.text ?? '', isEmpty);

      expect(find.text('Add another'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);

      expect(find.text('Continue'), findsOneWidget);
      expect(continueEnabled(tester), isFalse);
    });

    testWidgets(
        'STORY-001 AC-2: tapping Add another appends a new empty name field with an ✕ remove button',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);

      await tester.tap(find.text('Add another'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets(
        'STORY-001 AC-3: tapping ✕ removes that added field; the original first field never has an ✕',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      // Original field has no remove button.
      expect(find.byIcon(Icons.close), findsNothing);

      // Add a field, verify it has a remove button.
      await tester.tap(find.text('Add another'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Tap the remove button -> field is gone.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);

      // Add two fields and remove only the first added one.
      await tester.tap(find.text('Add another'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add another'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(3));
      expect(find.byIcon(Icons.close), findsNWidgets(2));

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets(
        'STORY-001 AC-4: Continue is enabled iff ≥2 trimmed non-empty fields; duplicates do NOT disable it',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(continueEnabled(tester), isFalse, reason: 'starts with one empty field');

      // One non-empty name => still disabled (need ≥2).
      await tester.enterText(find.byType(TextField).at(0), 'Alice');
      await tester.pumpAndSettle();
      expect(continueEnabled(tester), isFalse, reason: 'only 1 valid name');

      // Add a second field, fill it -> enabled.
      await tester.tap(find.text('Add another'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'Bob');
      await tester.pumpAndSettle();
      expect(continueEnabled(tester), isTrue, reason: '2 unique non-empty names');

      // Make the names duplicates (case-insensitive) -> still enabled per the
      // amended AC-4. The duplicate check only fires on Continue tap (AC-5).
      await tester.enterText(find.byType(TextField).at(1), 'ALICE');
      await tester.pumpAndSettle();
      expect(continueEnabled(tester), isTrue,
          reason: 'duplicates do NOT disable Continue under amended AC-4');

      // No duplicate indicator while typing, ever.
      expect(find.text('Duplicate name'), findsNothing,
          reason: 'AC-6: no duplicate indicator during typing');

      // Whitespace-only in first field => count drops to 1 valid -> disabled.
      await tester.enterText(find.byType(TextField).at(0), '   ');
      await tester.pumpAndSettle();
      expect(continueEnabled(tester), isFalse,
          reason: 'whitespace counts as empty');
    });

    testWidgets(
        'STORY-001 AC-5: tapping Continue with duplicates shows the indicator AND does not navigate AND does not commit state',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      // Two fields, duplicates by case-insensitivity + whitespace trim.
      await tester.tap(find.text('Add another'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '  Alice ');
      await tester.enterText(find.byType(TextField).at(1), 'alice');
      await tester.pumpAndSettle();

      // No indicator yet — typing should not reveal it.
      expect(find.text('Duplicate name'), findsNothing,
          reason: 'indicator must not show until Continue is tapped');

      // Continue is enabled (≥2 non-empty) per AC-4.
      expect(continueEnabled(tester), isTrue);

      // Tap Continue: indicator appears, no navigation, state unchanged.
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Duplicate name'), findsAtLeastNWidgets(1),
          reason: 'duplicate indicator must appear on Continue tap');
      expect(continueCalled, isFalse,
          reason: 'navigation must NOT occur when duplicates exist');
      expect(billState.people, isEmpty,
          reason: 'billState.people must NOT be modified when duplicates exist');
    });

    testWidgets(
        'STORY-001 AC-6: empty or whitespace-only fields disable Continue without showing any indicator; duplicate indicators do not appear during typing',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      // Initial: one empty field. Disabled + no indicator.
      expect(continueEnabled(tester), isFalse);
      expect(find.text('Duplicate name'), findsNothing);

      // Add a field, both empty.
      await tester.tap(find.text('Add another'));
      await tester.pumpAndSettle();
      expect(continueEnabled(tester), isFalse);
      expect(find.text('Duplicate name'), findsNothing);

      // Both whitespace-only.
      await tester.enterText(find.byType(TextField).at(0), '   ');
      await tester.enterText(find.byType(TextField).at(1), '\t');
      await tester.pumpAndSettle();
      expect(continueEnabled(tester), isFalse);
      expect(find.text('Duplicate name'), findsNothing);

      // Type "Sara" in field 0 and "Sarah" in field 1; while typing "Sara"
      // briefly in field 1 (substring of Sarah), no indicator must appear.
      await tester.enterText(find.byType(TextField).at(0), 'Sara');
      await tester.enterText(find.byType(TextField).at(1), 'Sara');
      await tester.pumpAndSettle();
      expect(find.text('Duplicate name'), findsNothing,
          reason: 'no indicator during typing even if names momentarily match');
    });

    testWidgets(
        'STORY-001 AC-7: Continue with unique trimmed non-empty names commits to bill state in order and triggers navigation',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.enterText(find.byType(TextField).at(0), '  Alice  ');
      await tester.tap(find.text('Add another'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'Bob');
      await tester.pumpAndSettle();

      expect(continueEnabled(tester), isTrue);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(billState.people, equals(<String>['Alice', 'Bob']));
      expect(continueCalled, isTrue);
    });
  });
}
