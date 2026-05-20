import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:bill_split/firebase_options.dart';
import 'package:bill_split/router.dart';
import 'package:bill_split/services/backend_client.dart';
import 'package:bill_split/services/extraction_client.dart';
import 'package:bill_split/services/image_acquirer.dart';
import 'package:bill_split/services/image_resizer.dart';
import 'package:bill_split/state/bill_state.dart';
import 'package:bill_split/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAuth.instance.signInAnonymously();

  const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: BackendClient.defaultLocalBaseUrl,
  );

  final backendClient = BackendClient(
    baseUrl: backendUrl,
    idTokenProvider: () async =>
        FirebaseAuth.instance.currentUser?.getIdToken(),
  );

  final billState = BillState();
  final ExtractionClient extractor = BackendExtractionClient(backendClient);
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
  final ExtractionClient extractor;
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
