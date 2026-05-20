// FR-007 / edge case EC-2: when extraction returns zero items, UploadScreen
// swaps to the same manual-entry surface used for failures.
import 'dart:typed_data';

import 'package:bill_splitter/features/bill/data/extract_repository.dart';
import 'package:bill_splitter/features/bill/screens/upload_screen.dart';
import 'package:bill_splitter/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyRepo implements ExtractRepository {
  @override
  Future<ExtractResult> extract(Uint8List bytes) async {
    return ExtractResult(items: const [], taxAmount: null, serviceAmount: null);
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
  testWidgets('FR-007: zero-items response shows manual entry — onSuccess does NOT fire yet',
      (tester) async {
    ExtractResult? success;

    await tester.pumpWidget(_wrap(UploadScreen(
      repository: _EmptyRepo(),
      pickImage: (_) async => Uint8List.fromList([1, 2, 3]),
      onSuccess: (r) => success = r,
      onFailure: (_) {},
    )));

    await tester.tap(find.byKey(const Key('upload-camera')));
    await tester.pumpAndSettle();

    // Manual entry surface visible.
    expect(find.byKey(const Key('manual-entry-surface')), findsOneWidget);
    expect(find.byKey(const Key('manual-item-name-0')), findsOneWidget);

    // onSuccess should NOT have fired with the empty list — the user must
    // type at least one item and tap Done.
    expect(success, isNull);
  });
}
