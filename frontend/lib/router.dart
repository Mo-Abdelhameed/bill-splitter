import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:bill_split/screens/assignment_screen.dart';
import 'package:bill_split/screens/capture_screen.dart';
import 'package:bill_split/screens/extraction_screen.dart';
import 'package:bill_split/screens/people_screen.dart';
import 'package:bill_split/screens/totals_screen.dart';
import 'package:bill_split/services/extraction_client.dart';
import 'package:bill_split/services/image_acquirer.dart';
import 'package:bill_split/services/image_resizer.dart';
import 'package:bill_split/state/bill_state.dart';

GoRouter createRouter({
  required BillState billState,
  required ExtractionClient extractor,
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
          onContinue: () => context.push('/capture'),
        ),
      ),
      GoRoute(
        path: '/capture',
        builder: (BuildContext context, GoRouterState state) => CaptureScreen(
          billState: billState,
          acquirer: acquirer,
          resizer: resizer,
          onContinue: () => context.push('/extract'),
        ),
      ),
      GoRoute(
        path: '/extract',
        builder: (BuildContext context, GoRouterState state) =>
            ExtractionScreen(
          billState: billState,
          extractor: extractor,
          onContinue: () => context.push('/assign'),
        ),
      ),
      GoRoute(
        path: '/assign',
        builder: (BuildContext context, GoRouterState state) =>
            AssignmentScreen(
          billState: billState,
          onContinue: () => context.push('/totals'),
        ),
      ),
      GoRoute(
        path: '/totals',
        builder: (BuildContext context, GoRouterState state) =>
            TotalsScreen(billState: billState),
      ),
    ],
  );
}
