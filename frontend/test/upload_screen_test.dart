import 'dart:typed_data';

import 'package:bill_splitter/features/bill/data/extract_repository.dart';
import 'package:bill_splitter/features/bill/model/item.dart';
import 'package:bill_splitter/features/bill/screens/upload_screen.dart';
import 'package:bill_splitter/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

class _FakeRepository implements ExtractRepository {
  _FakeRepository();
  int callCount = 0;
  Uint8List? lastBytes;

  @override
  Future<ExtractResult> extract(Uint8List bytes) async {
    callCount += 1;
    lastBytes = bytes;
    return ExtractResult(
      items: [Item.create(name: 'Foul', quantity: 1, unitPrice: 25, source: ItemSource.extracted)],
      taxAmount: null,
      serviceAmount: null,
    );
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
  testWidgets('FR-003: tapping camera invokes pickImage with camera source and submits',
      (tester) async {
    final fakeBytes = Uint8List.fromList(List.filled(32, 1));
    ImageSource? capturedSource;
    final repo = _FakeRepository();
    ExtractResult? captured;

    Future<Uint8List?> fakePicker(ImageSource source) async {
      capturedSource = source;
      return fakeBytes;
    }

    await tester.pumpWidget(_wrap(UploadScreen(
      repository: repo,
      pickImage: fakePicker,
      onSuccess: (r) => captured = r,
      onFailure: (_) {},
    )));

    await tester.tap(find.byKey(const Key('upload-camera')));
    await tester.pumpAndSettle();

    expect(capturedSource, ImageSource.camera);
    expect(repo.callCount, 1);
    expect(repo.lastBytes, fakeBytes);
    expect(captured, isNotNull);
    expect(captured!.items, hasLength(1));
  });

  testWidgets('FR-003: tapping gallery invokes pickImage with gallery source and submits',
      (tester) async {
    final fakeBytes = Uint8List.fromList(List.filled(16, 2));
    ImageSource? capturedSource;
    final repo = _FakeRepository();

    Future<Uint8List?> fakePicker(ImageSource source) async {
      capturedSource = source;
      return fakeBytes;
    }

    await tester.pumpWidget(_wrap(UploadScreen(
      repository: repo,
      pickImage: fakePicker,
      onSuccess: (_) {},
      onFailure: (_) {},
    )));

    await tester.tap(find.byKey(const Key('upload-gallery')));
    await tester.pumpAndSettle();

    expect(capturedSource, ImageSource.gallery);
    expect(repo.callCount, 1);
  });

  testWidgets('FR-003: cancelling the picker does not call the repository', (tester) async {
    final repo = _FakeRepository();

    Future<Uint8List?> fakePicker(ImageSource _) async => null;

    await tester.pumpWidget(_wrap(UploadScreen(
      repository: repo,
      pickImage: fakePicker,
      onSuccess: (_) {},
      onFailure: (_) {},
    )));

    await tester.tap(find.byKey(const Key('upload-camera')));
    await tester.pumpAndSettle();

    expect(repo.callCount, 0);
  });
}
