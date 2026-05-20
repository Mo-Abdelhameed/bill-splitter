// FR-020: the app jumps straight into the add-people screen on launch — no
// welcome screen, tutorial, or onboarding flow.
//
// This test guards against future drift by reading lib/app.dart and
// asserting that the router's initial location is /people and that no
// welcome/onboarding route is registered.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FR-020: initial route is /people and no welcome/onboarding routes exist', () {
    final source = File('lib/app.dart').readAsStringSync();
    expect(source, contains("initialLocation: '/people'"));
    final lowered = source.toLowerCase();
    expect(lowered, isNot(contains('/welcome')));
    expect(lowered, isNot(contains('/onboarding')));
  });
}
