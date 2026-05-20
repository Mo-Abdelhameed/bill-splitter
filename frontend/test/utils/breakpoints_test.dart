import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bill_split/utils/breakpoints.dart';

void main() {
  group('Breakpoints', () {
    Widget sizedHost(double width, void Function(Breakpoint) onBuild) {
      return MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: Builder(
          builder: (BuildContext context) {
            onBuild(breakpointFor(context));
            return const SizedBox.shrink();
          },
        ),
      );
    }

    testWidgets('breakpoints: width 320 returns Breakpoint.phonePortrait', (tester) async {
      late Breakpoint resolved;
      await tester.pumpWidget(sizedHost(320, (b) => resolved = b));
      expect(resolved, Breakpoint.phonePortrait);
    });

    testWidgets('breakpoints: width 599 returns Breakpoint.phonePortrait', (tester) async {
      late Breakpoint resolved;
      await tester.pumpWidget(sizedHost(599, (b) => resolved = b));
      expect(resolved, Breakpoint.phonePortrait);
    });

    testWidgets('breakpoints: width 600 returns Breakpoint.phoneLandscapeOrSmallTablet', (tester) async {
      late Breakpoint resolved;
      await tester.pumpWidget(sizedHost(600, (b) => resolved = b));
      expect(resolved, Breakpoint.phoneLandscapeOrSmallTablet);
    });

    testWidgets('breakpoints: width 900 returns Breakpoint.tablet', (tester) async {
      late Breakpoint resolved;
      await tester.pumpWidget(sizedHost(900, (b) => resolved = b));
      expect(resolved, Breakpoint.tablet);
    });

    testWidgets('breakpoints: width 1200 returns Breakpoint.tablet', (tester) async {
      late Breakpoint resolved;
      await tester.pumpWidget(sizedHost(1200, (b) => resolved = b));
      expect(resolved, Breakpoint.tablet);
    });
  });
}
