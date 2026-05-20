import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:bill_split/services/image_resizer.dart';

void main() {
  group('ImageResizerImpl (FR-002 resize math)', () {
    final resizer = ImageResizerImpl();

    Uint8List makePng(int width, int height) {
      final image = img.Image(width: width, height: height);
      // Fill with a single color so encoding doesn't optimize-away dimensions.
      img.fill(image, color: img.ColorRgb8(128, 128, 128));
      return Uint8List.fromList(img.encodePng(image));
    }

    test(
        'FR-002: a 3200x2000 image resizes so its longest edge is 1600 (aspect ratio preserved)',
        () async {
      final input = makePng(3200, 2000);
      final output = await resizer.resize(input, maxLongEdge: 1600);

      final decoded = img.decodePng(output)!;
      expect(decoded.width, 1600);
      expect(decoded.height, 1000);
    });

    test(
        'FR-002: a 1000x2400 (taller-than-wide) image resizes so its longest edge is 1600',
        () async {
      final input = makePng(1000, 2400);
      final output = await resizer.resize(input, maxLongEdge: 1600);

      final decoded = img.decodePng(output)!;
      // 2400 → 1600 (scale 2/3); 1000 × 2/3 ≈ 666.67 → 666 (rounded down)
      expect(decoded.height, 1600);
      expect(decoded.width, inInclusiveRange(665, 667));
    });

    test(
        'FR-002: a 1000x800 image (both edges ≤1600) is returned unchanged in dimensions',
        () async {
      final input = makePng(1000, 800);
      final output = await resizer.resize(input, maxLongEdge: 1600);

      final decoded = img.decodePng(output)!;
      expect(decoded.width, 1000);
      expect(decoded.height, 800);
    });
  });
}
