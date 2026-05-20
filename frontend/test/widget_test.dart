// Minimal smoke test: the app boots without throwing.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:bill_split/main.dart';
import 'package:bill_split/services/extraction_client.dart';
import 'package:bill_split/services/image_acquirer.dart';
import 'package:bill_split/services/image_resizer.dart';
import 'package:bill_split/state/bill_state.dart';

class _StubExtractor implements ExtractionClient {
  @override
  Future<ExtractionResult> extract(Uint8List imageBytes) async =>
      const ExtractionResult.empty();
}

class _StubAcquirer implements ImageAcquirer {
  @override
  Future<Uint8List?> takePhoto() async => null;
  @override
  Future<Uint8List?> pickFromGallery() async => null;
  @override
  Future<void> openAppSettings() async {}
}

class _StubResizer implements ImageResizer {
  @override
  Future<Uint8List> resize(Uint8List bytes, {required int maxLongEdge}) async =>
      bytes;
}

void main() {
  testWidgets('FR-smoke: app boots without exception', (WidgetTester tester) async {
    await tester.pumpWidget(BillSplitApp(
      billState: BillState(),
      extractor: _StubExtractor(),
      acquirer: _StubAcquirer(),
      resizer: _StubResizer(),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
