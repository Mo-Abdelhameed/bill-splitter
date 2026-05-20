import 'package:bill_splitter/features/bill/model/person.dart';
import 'package:bill_splitter/features/bill/screens/people_screen.dart';
import 'package:bill_splitter/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
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
}

Future<void> _addPerson(WidgetTester tester, String name) async {
  await tester.enterText(find.byType(TextField), name);
  await tester.tap(find.byKey(const Key('add-person-button')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('FR-001: Next is disabled with fewer than 2 people', (tester) async {
    final captured = <List<Person>>[];
    await tester.pumpWidget(_wrap(PeopleScreen(onProceed: captured.add)));

    final nextFinder = find.byKey(const Key('people-next-button'));

    // Zero people: tapping Next should not fire onProceed.
    await tester.tap(nextFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(captured, isEmpty);

    // One person: still no callback.
    await _addPerson(tester, 'Mo');
    await tester.tap(nextFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(captured, isEmpty);

    // Two people: callback fires with the list.
    await _addPerson(tester, 'Sara');
    await tester.tap(nextFinder);
    await tester.pumpAndSettle();
    expect(captured, hasLength(1));
    expect(captured.single.map((p) => p.name).toList(), ['Mo', 'Sara']);
  });

  testWidgets('FR-001: removing a person below 2 re-disables Next', (tester) async {
    final captured = <List<Person>>[];
    await tester.pumpWidget(_wrap(PeopleScreen(onProceed: captured.add)));

    await _addPerson(tester, 'A');
    await _addPerson(tester, 'B');

    // Remove the first person -> back to 1 -> Next must not fire.
    await tester.tap(find.byKey(const Key('remove-person-0')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('people-next-button')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(captured, isEmpty);
  });
}
