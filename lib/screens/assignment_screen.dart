import 'package:flutter/material.dart';

/// Placeholder destination for the extraction screen's "Continue" navigation.
/// The real Assignment screen — where people get tied to items — is the
/// subject of a future story.
class AssignmentScreen extends StatelessWidget {
  const AssignmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assign items')),
      body: const Center(
        child: Text('Assignment screen — coming in a later story.'),
      ),
    );
  }
}
