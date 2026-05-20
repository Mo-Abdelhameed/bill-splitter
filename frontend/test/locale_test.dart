import 'package:bill_splitter/core/language_toggle.dart';
import 'package:bill_splitter/core/locale.dart';
import 'package:bill_splitter/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestHost extends StatefulWidget {
  const _TestHost({required this.controller});
  final LocaleController controller;

  @override
  State<_TestHost> createState() => _TestHostState();
}

class _TestHostState extends State<_TestHost> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: widget.controller.locale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Title'),
          actions: [LanguageToggleButton(controller: widget.controller)],
        ),
        body: Builder(
          builder: (context) {
            final dir = Directionality.of(context);
            return Center(
              key: const Key('direction-marker'),
              child: Text(dir == TextDirection.rtl ? 'RTL' : 'LTR'),
            );
          },
        ),
      ),
    );
  }
}

void main() {
  testWidgets('FR-019: tapping the AppBar toggle flips layout to RTL and persists across rebuild',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = await LocaleController.load();

    await tester.pumpWidget(_TestHost(controller: controller));
    expect(find.text('LTR'), findsOneWidget);
    expect(find.text('RTL'), findsNothing);

    // Tap the toggle (must be reachable from the AppBar).
    await tester.tap(find.byKey(const Key('language-toggle-button')));
    await tester.pumpAndSettle();

    expect(find.text('RTL'), findsOneWidget);
    expect(find.text('LTR'), findsNothing);

    // SC-006 persistence: a fresh LocaleController loads the saved choice.
    final reloaded = await LocaleController.load();
    expect(reloaded.locale.languageCode, 'ar');
  });
}
