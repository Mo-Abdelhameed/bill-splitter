import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/api_client.dart';
import 'core/bill_controller.dart';
import 'core/errors.dart';
import 'core/language_toggle.dart';
import 'core/locale.dart';
import 'core/theme.dart';
import 'features/bill/data/extract_repository.dart';
import 'features/bill/screens/assign_screen.dart';
import 'features/bill/screens/items_screen.dart';
import 'features/bill/screens/people_screen.dart';
import 'features/bill/screens/totals_screen.dart';
import 'features/bill/screens/upload_screen.dart';
import 'l10n/app_localizations.dart';

class BillSplitterApp extends StatefulWidget {
  const BillSplitterApp({super.key, required this.localeController});
  final LocaleController localeController;

  @override
  State<BillSplitterApp> createState() => _BillSplitterAppState();
}

class _BillSplitterAppState extends State<BillSplitterApp> {
  final BillController _bill = BillController();
  late final ExtractRepository _repo = HttpExtractRepository(buildApiClient());

  late final GoRouter _router = GoRouter(
    initialLocation: '/people',
    routes: [
      GoRoute(
        path: '/people',
        builder: (context, state) => PeopleScreen(
          onProceed: (people) {
            _bill.setPeople(people);
            context.go('/upload');
          },
        ),
      ),
      GoRoute(
        path: '/upload',
        builder: (context, state) => UploadScreen(
          repository: _repo,
          onSuccess: (result) {
            _bill.setExtractResult(result);
            context.go('/items');
          },
          onFailure: (err) {
            // UploadScreen handles inline manual fallback for extraction errors.
            // Anything that bubbles here is an unexpected programming error.
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(describeError(context, err))),
            );
          },
        ),
      ),
      GoRoute(
        path: '/items',
        builder: (context, state) => ItemsScreen(
          initialItems: _bill.items,
          initialTaxAmount: _bill.taxAmount,
          initialServiceAmount: _bill.serviceAmount,
          onProceed: (result) {
            _bill.setItemsAndCharges(
              items: result.items,
              taxAmount: result.taxAmount,
              serviceAmount: result.serviceAmount,
            );
            context.go('/assign');
          },
        ),
      ),
      GoRoute(
        path: '/assign',
        builder: (context, state) => AssignScreen(
          people: _bill.people,
          items: _bill.items,
          initialAssignments: _bill.assignments,
          onProceed: (assignments) {
            _bill.setAssignments(assignments);
            context.go('/totals');
          },
        ),
      ),
      GoRoute(
        path: '/totals',
        builder: (context, state) => TotalsScreen(
          people: _bill.people,
          items: _bill.items,
          assignments: _bill.assignments,
          taxAmount: _bill.taxAmount,
          serviceAmount: _bill.serviceAmount,
          onStartNewBill: () {
            _bill.reset();
            context.go('/people');
          },
        ),
      ),
      // /items is the US5 editing surface — not yet implemented. The flow
      // currently bypasses it: extracted items go straight to /assign.
    ],
  );

  @override
  void initState() {
    super.initState();
    widget.localeController.addListener(_onLocaleChange);
  }

  @override
  void dispose() {
    widget.localeController.removeListener(_onLocaleChange);
    _bill.dispose();
    super.dispose();
  }

  void _onLocaleChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Bill Splitter',
      theme: buildLightTheme(),
      locale: widget.localeController.locale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _router,
      // FR-019: the language toggle is reachable from every screen by floating
      // it above whichever route is currently mounted.
      builder: (context, child) {
        return Stack(
          children: [
            ?child,
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, right: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: LanguageToggleButton(controller: widget.localeController),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
