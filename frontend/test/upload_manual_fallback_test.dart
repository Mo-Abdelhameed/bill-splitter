// FR-007 + SC-005: when extraction fails (network or backend error), the
// UploadScreen swaps inline to a manual-entry surface. The user types items
// in by hand and proceeds via the same onSuccess pathway as extraction.
import 'dart:typed_data';

import 'package:bill_splitter/core/errors.dart';
import 'package:bill_splitter/features/bill/data/extract_repository.dart';
import 'package:bill_splitter/features/bill/screens/upload_screen.dart';
import 'package:bill_splitter/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingRepo implements ExtractRepository {
  @override
  Future<ExtractResult> extract(Uint8List bytes) async {
    throw NetworkError('offline');
  }
}

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

void main() {
  testWidgets('FR-007: network error swaps the upload surface to manual entry inline',
      (tester) async {
    ExtractResult? success;
    final repo = _FailingRepo();

    await tester.pumpWidget(_wrap(UploadScreen(
      repository: repo,
      pickImage: (_) async => Uint8List.fromList([1, 2, 3]),
      onSuccess: (r) => success = r,
      onFailure: (_) {},
    )));

    await tester.tap(find.byKey(const Key('upload-camera')));
    await tester.pumpAndSettle();

    // The inline manual-entry surface is visible.
    expect(find.byKey(const Key('manual-entry-surface')), findsOneWidget);
    expect(find.byKey(const Key('manual-item-name-0')), findsOneWidget);
    expect(find.byKey(const Key('manual-item-price-0')), findsOneWidget);
    expect(find.byKey(const Key('manual-done-button')), findsOneWidget);

    // No top-level onFailure escape — the screen stayed put.
    expect(success, isNull);
  });

  testWidgets('FR-007: typing items in manual entry and tapping Done fires onSuccess',
      (tester) async {
    ExtractResult? success;
    final repo = _FailingRepo();

    await tester.pumpWidget(_wrap(UploadScreen(
      repository: repo,
      pickImage: (_) async => Uint8List.fromList([1, 2, 3]),
      onSuccess: (r) => success = r,
      onFailure: (_) {},
    )));

    await tester.tap(find.byKey(const Key('upload-camera')));
    await tester.pumpAndSettle();

    // Fill in one item.
    await tester.enterText(find.byKey(const Key('manual-item-name-0')), 'Koshary');
    await tester.enterText(find.byKey(const Key('manual-item-price-0')), '55');

    // Add a second item and fill it.
    await tester.tap(find.byKey(const Key('manual-add-item-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('manual-item-name-1')), 'Cola');
    await tester.enterText(find.byKey(const Key('manual-item-price-1')), '30');

    await tester.tap(find.byKey(const Key('manual-done-button')));
    await tester.pumpAndSettle();

    expect(success, isNotNull);
    expect(success!.items, hasLength(2));
    expect(success!.items[0].name, 'Koshary');
    expect(success!.items[0].unitPrice, 55);
    expect(success!.items[1].name, 'Cola');
    expect(success!.items[1].unitPrice, 30);
    expect(success!.taxAmount, isNull);
    expect(success!.serviceAmount, isNull);
  });
}
