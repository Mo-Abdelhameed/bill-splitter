import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bill_split/widgets/loading_state.dart';

void main() {
  group('LoadingState', () {
    testWidgets('LoadingState: with phase=loading renders a centered CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LoadingState(
          phase: LoadingPhase.loading,
          child: Text('content'),
        ),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('content'), findsNothing);
    });

    testWidgets('LoadingState: with phase=idle renders the child widget', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LoadingState(
          phase: LoadingPhase.idle,
          child: Text('content'),
        ),
      ));
      expect(find.text('content'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('LoadingState: with phase=error renders the errorChild', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LoadingState(
          phase: LoadingPhase.error,
          errorChild: Text('something went wrong'),
          child: Text('content'),
        ),
      ));
      expect(find.text('something went wrong'), findsOneWidget);
      expect(find.text('content'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
