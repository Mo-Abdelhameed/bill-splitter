import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:bill_split/router.dart';
import 'package:bill_split/services/gemini_extractor.dart';
import 'package:bill_split/services/image_acquirer.dart';
import 'package:bill_split/services/image_resizer.dart';
import 'package:bill_split/state/bill_state.dart';
import 'package:bill_split/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env missing or unreadable — proceed with no env vars.
  }

  String envValue(String key) {
    if (!dotenv.isInitialized) return '';
    return dotenv.env[key] ?? '';
  }

  final billState = BillState();
  final extractor = GeminiExtractorImpl(apiKey: envValue('GEMINI_API_KEY'));
  final acquirer = ImagePickerAcquirer();
  final resizer = ImageResizerImpl();

  runApp(BillSplitApp(
    billState: billState,
    extractor: extractor,
    acquirer: acquirer,
    resizer: resizer,
  ));
}

class BillSplitApp extends StatelessWidget {
  final BillState billState;
  final GeminiExtractor extractor;
  final ImageAcquirer acquirer;
  final ImageResizer resizer;

  const BillSplitApp({
    super.key,
    required this.billState,
    required this.extractor,
    required this.acquirer,
    required this.resizer,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Bill Split',
      theme: lightTheme,
      darkTheme: darkTheme,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[
        Locale('en'),
        Locale('ar'),
      ],
      routerConfig: createRouter(
        billState: billState,
        extractor: extractor,
        acquirer: acquirer,
        resizer: resizer,
      ),
    );
  }
}
