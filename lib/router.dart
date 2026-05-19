import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:bill_split/screens/assignment_screen.dart';
import 'package:bill_split/screens/capture_screen.dart';
import 'package:bill_split/screens/extraction_screen.dart';
import 'package:bill_split/screens/people_screen.dart';
import 'package:bill_split/services/gemini_extractor.dart';
import 'package:bill_split/services/image_acquirer.dart';
import 'package:bill_split/services/image_resizer.dart';
import 'package:bill_split/state/bill_state.dart';

GoRouter createRouter({
  required BillState billState,
  required GeminiExtractor extractor,
  required ImageAcquirer acquirer,
  required ImageResizer resizer,
}) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) => PeopleScreen(
          billState: billState,
          onContinue: () => context.go('/capture'),
        ),
      ),
      GoRoute(
        path: '/capture',
        builder: (BuildContext context, GoRouterState state) => CaptureScreen(
          billState: billState,
          acquirer: acquirer,
          resizer: resizer,
          onContinue: () => context.go('/extract'),
        ),
      ),
      GoRoute(
        path: '/extract',
        builder: (BuildContext context, GoRouterState state) =>
            ExtractionScreen(
          billState: billState,
          extractor: extractor,
          onContinue: () => context.go('/assign'),
        ),
      ),
      GoRoute(
        path: '/assign',
        builder: (BuildContext context, GoRouterState state) =>
            const AssignmentScreen(),
      ),
    ],
  );
}
