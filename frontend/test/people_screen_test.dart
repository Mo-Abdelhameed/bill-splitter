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

    // Zero people: Next is disabled.
    final nextFinder = find.byKey(const Key('people-next-button'));
    expect(tester.widget<ElevatedButton>(nextFinder).onPressed, isNull);

    // One person: still disabled.
    await _addPerson(tester, 'Mo');
    expect(tester.widget<ElevatedButton>(nextFinder).onPressed, isNull);

    // Two people: enabled.
    await _addPerson(tester, 'Sara');
    expect(tester.widget<ElevatedButton>(nextFinder).onPressed, isNotNull);

    // Tapping Next forwards the people list.
    await tester.tap(nextFinder);
    await tester.pumpAndSettle();
    expect(captured, hasLength(1));
    expect(captured.single.map((p) => p.name).toList(), ['Mo', 'Sara']);
  });

  testWidgets('FR-001: removing a person below 2 re-disables Next', (tester) async {
    await tester.pumpWidget(_wrap(PeopleScreen(onProceed: (_) {})));

    await _addPerson(tester, 'A');
    await _addPerson(tester, 'B');

    final nextFinder = find.byKey(const Key('people-next-button'));
    expect(tester.widget<ElevatedButton>(nextFinder).onPressed, isNotNull);

    // Remove the first person -> back to 1 -> Next disabled.
    await tester.tap(find.byKey(const Key('remove-person-0')));
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(nextFinder).onPressed, isNull);
  });
}
