import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../model/assignment.dart';
import '../model/item.dart';
import '../model/person.dart';

class _WeightSheet extends StatefulWidget {
  const _WeightSheet({
    required this.item,
    required this.people,
    required this.personIds,
    required this.initialWeights,
  });
  final Item item;
  final List<Person> people;
  final Set<String> personIds;
  final Map<String, num>? initialWeights;

  @override
  State<_WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends State<_WeightSheet> {
  late final Map<String, TextEditingController> _controllers = {
    for (final pid in widget.personIds)
      pid: TextEditingController(
        text: (widget.initialWeights?[pid] ?? 1).toString(),
      ),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Weights for ${widget.item.name}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final pid in widget.personIds)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.people.firstWhere((p) => p.id == pid).name,
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      key: Key('weight-${widget.item.id}-$pid'),
                      controller: _controllers[pid],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(isDense: true),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          ElevatedButton(
            key: Key('weight-save-${widget.item.id}'),
            onPressed: () {
              final weights = <String, num>{};
              for (final pid in widget.personIds) {
                final raw = _controllers[pid]!.text.trim();
                final w = num.tryParse(raw);
                if (w == null || w <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All weights must be > 0.')),
                  );
                  return;
                }
                weights[pid] = w;
              }
              Navigator.of(context).pop(weights);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class AssignScreen extends StatefulWidget {
  const AssignScreen({
    super.key,
    required this.people,
    required this.items,
    required this.initialAssignments,
    required this.onProceed,
  });

  // People are locked here (FR-002) — list is immutable for this screen's life.
  final List<Person> people;
  final List<Item> items;
  final Map<String, Assignment> initialAssignments;
  final ValueChanged<Map<String, Assignment>> onProceed;

  @override
  State<AssignScreen> createState() => _AssignScreenState();
}

class _AssignScreenState extends State<AssignScreen> {
  late Map<String, Assignment> _assignments;

  @override
  void initState() {
    super.initState();
    _assignments = Map.of(widget.initialAssignments);
  }

  void _toggle(Item item, Person person) {
    setState(() {
      final existing = _assignments[item.id];
      if (existing == null) {
        _assignments[item.id] = Assignment(itemId: item.id, personIds: {person.id});
        return;
      }
      final next = Set<String>.from(existing.personIds);
      if (next.contains(person.id)) {
        next.remove(person.id);
      } else {
        next.add(person.id);
      }
      if (next.isEmpty) {
        _assignments.remove(item.id);
      } else {
        // Drop weights when membership changes — they no longer match.
        _assignments[item.id] = Assignment(itemId: item.id, personIds: next);
      }
    });
  }

  List<Item> get _unassignedItems => widget.items
      .where((i) => (_assignments[i.id]?.personIds ?? const <String>{}).isEmpty)
      .toList();

  bool get _allAssigned => _unassignedItems.isEmpty;

  Future<void> _openOverride(Item item) async {
    final current = _assignments[item.id];
    if (current == null || current.personIds.length < 2) return;

    final result = await showModalBottomSheet<Map<String, num>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => _WeightSheet(
        item: item,
        people: widget.people,
        personIds: current.personIds,
        initialWeights: current.weights,
      ),
    );

    if (result != null) {
      setState(() {
        _assignments[item.id] = Assignment(
          itemId: item.id,
          personIds: current.personIds,
          weights: result,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.assignScreenTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: widget.items.length,
                separatorBuilder: (_, _) => const Divider(height: 24),
                itemBuilder: (context, i) {
                  final item = widget.items[i];
                  final assigned = _assignments[item.id]?.personIds ?? const <String>{};
                  final hasOverride = (_assignments[item.id]?.weights) != null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.name} · ${item.lineTotal.toStringAsFixed(0)} ${l.currencyEgp}',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          IconButton(
                            key: Key('override-${item.id}'),
                            tooltip: 'Weights',
                            icon: Icon(
                              hasOverride ? Icons.tune : Icons.tune_outlined,
                              color: hasOverride
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            onPressed: assigned.length >= 2
                                ? () => _openOverride(item)
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final p in widget.people)
                            FilterChip(
                              key: Key('chip-${item.id}-${p.id}'),
                              label: Text(p.name),
                              selected: assigned.contains(p.id),
                              onSelected: (_) => _toggle(item, p),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            if (!_allAssigned)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${l.unassignedItemsBlocker} ${_unassignedItems.map((i) => i.name).join(", ")}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ElevatedButton(
              key: const Key('assign-view-totals'),
              onPressed: _allAssigned
                  ? () => widget.onProceed(Map.unmodifiable(_assignments))
                  : null,
              child: Text(l.viewTotalsButton),
            ),
          ],
        ),
      ),
    );
  }
}
