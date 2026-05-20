import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bill_split/screens/assignment_screen.dart';
import 'package:bill_split/state/bill_item.dart';
import 'package:bill_split/state/bill_state.dart';

/// Tests for AssignmentScreen (T030). Item identities are addressed via stable
/// `id` strings so the tests don't depend on UUID values; we hand the screen
/// pre-id'd items via [BillState].
void main() {
  group('AssignmentScreen', () {
    late BillState billState;
    late bool continueCalled;

    setUp(() {
      billState = BillState()
        ..people = <String>['Alice', 'Bob']
        ..items = <BillItem>[
          const BillItem(id: 'i1', name: 'pasta', price: 50),
          const BillItem(id: 'i2', name: 'salad', price: 30),
        ];
      continueCalled = false;
    });

    Widget buildSubject() => MaterialApp(
          home: AssignmentScreen(
            billState: billState,
            onContinue: () => continueCalled = true,
          ),
        );

    bool continueEnabled(WidgetTester tester) {
      final btn = tester
          .widget<ButtonStyleButton>(find.widgetWithText(ElevatedButton, 'Continue'));
      return btn.onPressed != null;
    }

    /// Drives the tap-modal assignment path: tap the item row, tick each named
    /// person, then dismiss the modal with 'Done'.
    Future<void> assignViaModal(
      WidgetTester tester, {
      required String itemId,
      required List<String> people,
    }) async {
      await tester.tap(find.byKey(ValueKey<String>('item-row-$itemId')));
      await tester.pumpAndSettle();
      for (final name in people) {
        await tester.tap(find.byKey(ValueKey<String>('assign-checkbox-$name')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'FR-005: each item row exposes a drop-target and the people strip contains a Draggable per person',
      (tester) async {
        await tester.pumpWidget(buildSubject());

        // One DragTarget per item.
        expect(find.byKey(const ValueKey<String>('item-row-i1')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('item-row-i2')), findsOneWidget);

        // One person-draggable per person.
        expect(find.byKey(const ValueKey<String>('person-draggable-Alice')),
            findsOneWidget);
        expect(find.byKey(const ValueKey<String>('person-draggable-Bob')),
            findsOneWidget);
      },
    );

    testWidgets(
      'FR-005: dragging a person onto an item records the assignment',
      (tester) async {
        await tester.pumpWidget(buildSubject());

        final from = tester
            .getCenter(find.byKey(const ValueKey<String>('person-draggable-Alice')));
        final to = tester.getCenter(find.byKey(const ValueKey<String>('item-row-i1')));

        final gesture = await tester.startGesture(from);
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.moveTo(to);
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(billState.assignments['i1'], isNotNull);
        expect(billState.assignments['i1']!.containsKey('Alice'), isTrue);
      },
    );

    testWidgets(
      'FR-005: tapping an item opens a modal with one checkbox per person (tap fallback)',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.tap(find.byKey(const ValueKey<String>('item-row-i1')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey<String>('assign-checkbox-Alice')),
            findsOneWidget);
        expect(find.byKey(const ValueKey<String>('assign-checkbox-Bob')),
            findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
      },
    );

    testWidgets(
      'FR-006: a person assigned to multiple items is recorded against each',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await assignViaModal(tester, itemId: 'i1', people: <String>['Alice']);
        await assignViaModal(tester, itemId: 'i2', people: <String>['Alice', 'Bob']);

        expect(billState.assignments['i1']!.containsKey('Alice'), isTrue);
        expect(billState.assignments['i2']!.containsKey('Alice'), isTrue);
        expect(billState.assignments['i2']!.containsKey('Bob'), isTrue);
      },
    );

    testWidgets(
      'FR-006: an item with multiple assignees shows a chip per assignee on its row',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await assignViaModal(tester, itemId: 'i1', people: <String>['Alice', 'Bob']);

        expect(find.byKey(const ValueKey<String>('assignee-chip-i1-Alice')),
            findsOneWidget);
        expect(find.byKey(const ValueKey<String>('assignee-chip-i1-Bob')),
            findsOneWidget);
      },
    );

    testWidgets(
      'FR-007: by default, every assignee gets weight 1.0 (equal split)',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await assignViaModal(tester, itemId: 'i1', people: <String>['Alice', 'Bob']);

        final weights = billState.assignments['i1']!;
        expect(weights['Alice'], 1.0);
        expect(weights['Bob'], 1.0);
      },
    );

    testWidgets(
      'FR-007a: long-pressing an assignee chip opens a weight editor; setting weight updates state',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await assignViaModal(tester, itemId: 'i1', people: <String>['Alice', 'Bob']);

        await tester
            .longPress(find.byKey(const ValueKey<String>('assignee-chip-i1-Alice')));
        await tester.pumpAndSettle();

        // The popover must show a labeled weight input.
        final weightField = find.byKey(const ValueKey<String>('weight-input-i1-Alice'));
        expect(weightField, findsOneWidget);

        await tester.enterText(weightField, '2');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(billState.assignments['i1']!['Alice'], 2.0);
        expect(billState.assignments['i1']!['Bob'], 1.0);
      },
    );

    testWidgets(
      'FR-011: Continue is disabled while any item has zero assignees',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        expect(continueEnabled(tester), isFalse, reason: 'no assignments yet');

        await assignViaModal(tester, itemId: 'i1', people: <String>['Alice']);
        expect(continueEnabled(tester), isFalse,
            reason: 'i2 still has zero assignees');

        await assignViaModal(tester, itemId: 'i2', people: <String>['Bob']);
        expect(continueEnabled(tester), isTrue,
            reason: 'every item now has ≥1 assignee');
      },
    );

    testWidgets(
      'FR-011: unassigned items show a visual indicator',
      (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byKey(const ValueKey<String>('unassigned-indicator-i1')),
            findsOneWidget);
        expect(find.byKey(const ValueKey<String>('unassigned-indicator-i2')),
            findsOneWidget);

        await assignViaModal(tester, itemId: 'i1', people: <String>['Alice']);

        expect(find.byKey(const ValueKey<String>('unassigned-indicator-i1')),
            findsNothing);
        expect(find.byKey(const ValueKey<String>('unassigned-indicator-i2')),
            findsOneWidget);
      },
    );

    testWidgets(
      'FR-008: Continue commits the assignment map to bill state and triggers navigation',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await assignViaModal(tester, itemId: 'i1', people: <String>['Alice']);
        await assignViaModal(tester, itemId: 'i2', people: <String>['Alice', 'Bob']);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
        await tester.pumpAndSettle();

        expect(continueCalled, isTrue);
        expect(billState.assignments['i1']!.keys.toSet(), <String>{'Alice'});
        expect(billState.assignments['i2']!.keys.toSet(), <String>{'Alice', 'Bob'});
      },
    );
  });
}
