import 'package:flutter_test/flutter_test.dart';

import 'package:bill_split/theme.dart';

void main() {
  group('Theme', () {
    test('theme: primary seed color is 0xFF1F5FBE', () {
      // Updated 2026-05-20 to match the UI design spec at
      // specs/001-bill-split-flow/ui/billsplit-standalone.html. Previously
      // Material Blue 700 (0xFF1976D2); the design moved to a slightly
      // muted royal blue (0xFF1F5FBE) used throughout the prototype.
      expect(seedColor.toARGB32(), 0xFF1F5FBE);
    });

    test('theme: surface color is 0xFFFAF8F4 (off-white)', () {
      expect(lightTheme.colorScheme.surface.toARGB32(), 0xFFFAF8F4);
    });

    test('theme: useMaterial3 is true', () {
      expect(lightTheme.useMaterial3, isTrue);
    });
  });
}
