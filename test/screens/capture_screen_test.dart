import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bill_split/screens/capture_screen.dart';
import 'package:bill_split/services/image_acquirer.dart';
import 'package:bill_split/services/image_resizer.dart';
import 'package:bill_split/state/bill_state.dart';

/// Hand-written fake acquirer — configurable per test.
class FakeImageAcquirer implements ImageAcquirer {
  Uint8List? takeResult;
  Uint8List? pickResult;
  Object? throwOnTake;
  Object? throwOnPick;
  int takeCount = 0;
  int pickCount = 0;
  int openSettingsCount = 0;

  @override
  Future<Uint8List?> takePhoto() async {
    takeCount++;
    if (throwOnTake != null) throw throwOnTake!;
    return takeResult;
  }

  @override
  Future<Uint8List?> pickFromGallery() async {
    pickCount++;
    if (throwOnPick != null) throw throwOnPick!;
    return pickResult;
  }

  @override
  Future<void> openAppSettings() async {
    openSettingsCount++;
  }
}

/// Hand-written fake resizer — records what it was asked to do and returns
/// either a configured result or the input bytes unchanged.
class FakeImageResizer implements ImageResizer {
  Uint8List? returnBytes;
  Uint8List? lastInput;
  int? lastMaxLongEdge;
  int resizeCount = 0;

  @override
  Future<Uint8List> resize(Uint8List bytes, {required int maxLongEdge}) async {
    resizeCount++;
    lastInput = bytes;
    lastMaxLongEdge = maxLongEdge;
    return returnBytes ?? bytes;
  }
}

void main() {
  group('CaptureScreen', () {
    late BillState billState;
    late FakeImageAcquirer acquirer;
    late FakeImageResizer resizer;
    late bool continueCalled;

    final originalBytes = Uint8List.fromList(<int>[10, 20, 30, 40, 50]);
    final resizedBytes = Uint8List.fromList(<int>[1, 2, 3]);

    setUp(() {
      billState = BillState();
      acquirer = FakeImageAcquirer();
      resizer = FakeImageResizer()..returnBytes = resizedBytes;
      continueCalled = false;
    });

    Widget buildSubject() => MaterialApp(
          home: CaptureScreen(
            billState: billState,
            acquirer: acquirer,
            resizer: resizer,
            onContinue: () => continueCalled = true,
          ),
        );

    testWidgets(
        'STORY-003 AC-1: initial render shows Take Photo + Pick from Gallery, no preview, no permission error, leaves billState.imageBytes unchanged',
        (tester) async {
      billState.imageBytes = Uint8List.fromList(<int>[99]); // sentinel
      await tester.pumpWidget(buildSubject());

      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Pick from Gallery'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.text('Use this photo'), findsNothing);
      expect(find.textContaining('permission denied'), findsNothing);
      expect(billState.imageBytes, equals(Uint8List.fromList(<int>[99])));
    });

    testWidgets(
        'STORY-003 AC-2: tapping Take Photo with camera permission granted invokes acquirer.takePhoto',
        (tester) async {
      acquirer.takeResult = null; // simulate user cancel after permission grant
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();

      expect(acquirer.takeCount, 1);
    });

    testWidgets(
        'STORY-003 AC-3: tapping Pick from Gallery with photo-library permission granted invokes acquirer.pickFromGallery',
        (tester) async {
      acquirer.pickResult = null;
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Pick from Gallery'));
      await tester.pumpAndSettle();

      expect(acquirer.pickCount, 1);
    });

    testWidgets(
        'STORY-003 AC-4: a returned image is resized with maxLongEdge=1600, stored in billState.imageBytes, and the screen enters the preview state',
        (tester) async {
      acquirer.takeResult = originalBytes;
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();

      expect(resizer.resizeCount, 1);
      expect(resizer.lastInput, equals(originalBytes));
      expect(resizer.lastMaxLongEdge, 1600);
      expect(billState.imageBytes, equals(resizedBytes));
      // Preview state visible:
      expect(find.text('Use this photo'), findsOneWidget);
      expect(find.text('Retake or repick'), findsOneWidget);
      // Initial CTAs gone:
      expect(find.text('Take Photo'), findsNothing);
      expect(find.text('Pick from Gallery'), findsNothing);
    });

    testWidgets(
        'STORY-003 AC-5: preview state renders an Image, plus Use this photo and Retake or repick buttons; original CTAs are hidden',
        (tester) async {
      acquirer.pickResult = originalBytes;
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('Pick from Gallery'));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Use this photo'), findsOneWidget);
      expect(find.text('Retake or repick'), findsOneWidget);
      expect(find.text('Take Photo'), findsNothing);
      expect(find.text('Pick from Gallery'), findsNothing);
    });

    testWidgets(
        'STORY-003 AC-6: tapping Use this photo triggers navigation (onContinue) without modifying billState.imageBytes',
        (tester) async {
      acquirer.takeResult = originalBytes;
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();

      final committedBefore = billState.imageBytes;
      expect(continueCalled, isFalse);

      await tester.tap(find.text('Use this photo'));
      await tester.pumpAndSettle();

      expect(continueCalled, isTrue);
      expect(billState.imageBytes, equals(committedBefore));
    });

    testWidgets(
        'STORY-003 AC-7: tapping Retake or repick clears billState.imageBytes to null and returns to the initial 2-CTA state',
        (tester) async {
      acquirer.takeResult = originalBytes;
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();
      expect(billState.imageBytes, equals(resizedBytes));

      await tester.tap(find.text('Retake or repick'));
      await tester.pumpAndSettle();

      expect(billState.imageBytes, isNull);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Pick from Gallery'), findsOneWidget);
      expect(find.text('Use this photo'), findsNothing);
    });

    testWidgets(
        'STORY-003 AC-8: cancelling the picker (null result) shows a "No image selected" snackbar and keeps the screen in the initial state with billState unchanged',
        (tester) async {
      billState.imageBytes = null;
      acquirer.takeResult = null; // user cancelled
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Take Photo'));
      await tester.pump(); // start async
      await tester.pump(const Duration(milliseconds: 10)); // settle snack

      expect(find.text('No image selected'), findsOneWidget);
      // Still in initial 2-CTA state.
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Pick from Gallery'), findsOneWidget);
      expect(billState.imageBytes, isNull);
    });

    testWidgets(
        'STORY-003 AC-9: camera permission denied shows an inline camera-denied error with an Open Settings button; Pick from Gallery still works',
        (tester) async {
      acquirer.throwOnTake =
          PermissionDeniedException(ImagePermissionSource.camera);
      acquirer.pickResult = originalBytes;
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();

      // Inline error visible (some text indicating camera permission denied)
      expect(
        find.byKey(const ValueKey<String>('camera-permission-error')),
        findsOneWidget,
      );
      // Open Settings button visible; tapping it calls acquirer.openAppSettings
      expect(find.text('Open Settings'), findsAtLeastNWidgets(1));
      await tester.tap(find.text('Open Settings').first);
      await tester.pump();
      expect(acquirer.openSettingsCount, 1);

      // Pick from Gallery still works:
      expect(find.text('Pick from Gallery'), findsOneWidget);
      await tester.tap(find.text('Pick from Gallery'));
      await tester.pumpAndSettle();
      expect(acquirer.pickCount, 1);
      expect(billState.imageBytes, equals(resizedBytes));
    });

    testWidgets(
        'STORY-003 AC-10: photo-library permission denied shows an inline gallery-denied error with Open Settings; Take Photo still works',
        (tester) async {
      acquirer.throwOnPick =
          PermissionDeniedException(ImagePermissionSource.gallery);
      acquirer.takeResult = originalBytes;
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Pick from Gallery'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('gallery-permission-error')),
        findsOneWidget,
      );
      expect(find.text('Open Settings'), findsAtLeastNWidgets(1));
      await tester.tap(find.text('Open Settings').first);
      await tester.pump();
      expect(acquirer.openSettingsCount, 1);

      expect(find.text('Take Photo'), findsOneWidget);
      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();
      expect(acquirer.takeCount, 1);
      expect(billState.imageBytes, equals(resizedBytes));
    });
  });
}
