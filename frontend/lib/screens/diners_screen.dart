import 'package:flutter/material.dart';

import '../main.dart';
import 'assignment_screen.dart';

class DinersScreen extends StatefulWidget {
  const DinersScreen({super.key});

  @override
  State<DinersScreen> createState() => _DinersScreenState();
}

class _DinersScreenState extends State<DinersScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final session = SessionScope.of(context);
    try {
      session.addDiner(_controller.text);
      _controller.clear();
      setState(() => _error = null);
    } on ArgumentError {
      setState(() => _error = 'Name cannot be empty');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final diners = session.diners;
    return Scaffold(
      appBar: AppBar(title: const Text('Who is splitting?')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _add(),
                    decoration: InputDecoration(
                      labelText: 'Add a diner',
                      errorText: _error,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(onPressed: _add, child: const Text('Add')),
              ],
            ),
          ),
          Expanded(
            child: diners.isEmpty
                ? const Center(child: Text('No diners yet — add at least one.'))
                : ListView.builder(
                    itemCount: diners.length,
                    itemBuilder: (context, i) {
                      final d = diners[i];
                      return ListTile(
                        leading: CircleAvatar(child: Text(d.name.characters.first.toUpperCase())),
                        title: Text(d.name),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => session.removeDiner(d.id),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: diners.isEmpty
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const AssignmentScreen(),
                        )),
                child: const Text('Continue to assignment'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
