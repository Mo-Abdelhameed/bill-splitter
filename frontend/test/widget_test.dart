import 'package:bill_splitter_app/models/models.dart';
import 'package:bill_splitter_app/screens/assignment_screen.dart';
import 'package:bill_splitter_app/screens/summary_screen.dart';
import 'package:bill_splitter_app/state/bill_session.dart';
import 'package:bill_splitter_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ExtractedReceipt _sampleReceipt() {
  return ExtractedReceipt.fromJson({
    'items': [
      {'name': 'Pizza', 'price': 14.0},
      {'name': 'Salad', 'price': 10.0},
    ],
    'charges': {'tax': 2.4, 'service': 3.6},
  });
}

Widget _wrap(BillSession session, Widget child) {
  return MaterialApp(
    home: SessionScope(session: session, child: child),
  );
}

void main() {
  group('AssignmentScreen', () {
    testWidgets('many-to-many toggling updates assignments', (tester) async {
      final session = BillSession()..setReceipt(_sampleReceipt());
      session.addDiner('Alice');
      session.addDiner('Bob');

      await tester.pumpWidget(_wrap(session, const AssignmentScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, 'Alice').first);
      await tester.pump();
      await tester.tap(find.widgetWithText(FilterChip, 'Bob').first);
      await tester.pump();

      final pizzaId = session.items.first.id;
      expect(session.assignments[pizzaId], {
        session.diners[0].id,
        session.diners[1].id,
      });
      expect(session.unassigned.length, 1);
      expect(session.unassigned.single.name, 'Salad');
    });

    testWidgets('unassigned banner shows when items have no diners',
        (tester) async {
      final session = BillSession()..setReceipt(_sampleReceipt());
      session.addDiner('Alice');
      await tester.pumpWidget(_wrap(session, const AssignmentScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining('unassigned'), findsOneWidget);
    });
  });

  group('SummaryScreen', () {
    testWidgets('per-diner totals shown', (tester) async {
      final session = BillSession()..setReceipt(_sampleReceipt());
      session.addDiner('Alice');
      session.addDiner('Bob');
      session.toggleAssignment(session.items[0].id, session.diners[0].id);
      session.toggleAssignment(session.items[1].id, session.diners[1].id);

      await tester.pumpWidget(_wrap(session, const SummaryScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Total'), findsNWidgets(2));
      expect(find.text('\$30.00'), findsWidgets);
    });

    testWidgets('tax override recomputes totals', (tester) async {
      final session = BillSession()..setReceipt(_sampleReceipt());
      session.addDiner('Alice');
      session.toggleAssignment(session.items[0].id, session.diners[0].id);
      session.toggleAssignment(session.items[1].id, session.diners[0].id);

      await tester.pumpWidget(_wrap(session, const SummaryScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Tax'), '0');
      await tester.pump();
      expect(session.charges.tax, 0);
      expect(session.computeTotals().perDiner.single.grandTotal,
          closeTo(27.6, 0.01));
    });

    testWidgets('finalize disabled while items unassigned', (tester) async {
      final session = BillSession()..setReceipt(_sampleReceipt());
      session.addDiner('Alice');
      session.toggleAssignment(session.items[0].id, session.diners[0].id);

      await tester.pumpWidget(_wrap(session, const SummaryScreen()));
      await tester.pumpAndSettle();

      final finalize = find.widgetWithText(FilledButton, 'Finalize');
      expect(finalize, findsOneWidget);
      final btn = tester.widget<FilledButton>(finalize);
      expect(btn.onPressed, isNull);
    });
  });
}
