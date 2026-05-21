import 'package:flutter/material.dart';

import '../main.dart';
import 'summary_screen.dart';

class AssignmentScreen extends StatelessWidget {
  const AssignmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final diners = session.diners;
    final items = session.items;
    final unassigned = session.unassigned;

    return Scaffold(
      appBar: AppBar(title: const Text('Assign items')),
      body: Column(
        children: [
          if (unassigned.isNotEmpty)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.all(12),
              child: Text(
                '${unassigned.length} unassigned item${unassigned.length == 1 ? '' : 's'}: '
                '${unassigned.map((i) => i.name).join(", ")}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final item = items[i];
                final assignees = session.assignments[item.id] ?? const <String>{};
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(item.name,
                                style: Theme.of(context).textTheme.titleMedium),
                          ),
                          Text('\$${item.price.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final d in diners)
                            FilterChip(
                              label: Text(d.name),
                              selected: assignees.contains(d.id),
                              onSelected: (_) =>
                                  session.toggleAssignment(item.id, d.id),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SummaryScreen(),
                )),
                child: const Text('See totals'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
