import 'package:flutter/material.dart';

import 'screens/capture_screen.dart';
import 'state/bill_session.dart';

void main() {
  runApp(const BillSplitterApp());
}

class BillSplitterApp extends StatefulWidget {
  const BillSplitterApp({super.key});

  @override
  State<BillSplitterApp> createState() => _BillSplitterAppState();
}

class _BillSplitterAppState extends State<BillSplitterApp> {
  final BillSession session = BillSession();

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: session,
      child: MaterialApp(
        title: 'Bill Splitter',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F6FEB)),
          useMaterial3: true,
        ),
        home: const CaptureScreen(),
      ),
    );
  }
}

class SessionScope extends InheritedNotifier<BillSession> {
  const SessionScope({super.key, required BillSession session, required super.child})
      : super(notifier: session);

  static BillSession of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope not found in widget tree');
    return scope!.notifier!;
  }
}
