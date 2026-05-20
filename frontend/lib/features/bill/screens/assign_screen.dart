import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/ui/bill_stepper.dart';
import '../../../core/ui/bottom_action_bar.dart';
import '../../../core/ui/display_title.dart';
import '../../../core/ui/inline_hint.dart';
import '../../../core/ui/person_avatar.dart';
import '../../../core/ui/pill_button.dart';
import '../../../l10n/app_localizations.dart';
import '../model/assignment.dart';
import '../model/item.dart';
import '../model/person.dart';

class AssignScreen extends StatefulWidget {
  const AssignScreen({
    super.key,
    required this.people,
    required this.items,
    required this.initialAssignments,
    required this.onProceed,
  });

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
      showDragHandle: true,
      backgroundColor: AppTokens.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
      appBar: AppBar(toolbarHeight: 36),
      body: Column(
        children: [
          const BillStepper(step: 3),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DisplayTitle.rich(
                  [
                    DisplayTitle.plain('Assign '),
                    DisplayTitle.accent('names'),
                    DisplayTitle.plain(' to items.'),
                  ],
                  size: 26,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap chips to assign. Long-press the weights icon for shared items.',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppTokens.onMuted),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              itemCount: widget.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final item = widget.items[i];
                final assigned = _assignments[item.id]?.personIds ?? const <String>{};
                final hasOverride = (_assignments[item.id]?.weights) != null;
                final isUnassigned = assigned.isEmpty;
                return _ItemCard(
                  item: item,
                  people: widget.people,
                  assignedIds: assigned,
                  hasOverride: hasOverride,
                  isUnassigned: isUnassigned,
                  currency: l.currencyEgp,
                  onToggle: (p) => _toggle(item, p),
                  onOverride: assigned.length >= 2 ? () => _openOverride(item) : null,
                );
              },
            ),
          ),
          BottomActionBar(
            child: Column(
              children: [
                if (!_allAssigned)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InlineHint(
                      message:
                          '${l.unassignedItemsBlocker} ${_unassignedItems.map((i) => i.name).join(", ")}',
                      tone: HintTone.warn,
                    ),
                  ),
                PillButton(
                  key: const Key('assign-view-totals'),
                  label: l.viewTotalsButton,
                  icon: Icons.arrow_forward,
                  iconAtEnd: true,
                  onPressed: _allAssigned
                      ? () => widget.onProceed(Map.unmodifiable(_assignments))
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.people,
    required this.assignedIds,
    required this.hasOverride,
    required this.isUnassigned,
    required this.currency,
    required this.onToggle,
    required this.onOverride,
  });

  final Item item;
  final List<Person> people;
  final Set<String> assignedIds;
  final bool hasOverride;
  final bool isUnassigned;
  final String currency;
  final ValueChanged<Person> onToggle;
  final VoidCallback? onOverride;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnassigned ? AppTokens.warnBorder : AppTokens.outlineSoft,
          width: isUnassigned ? 1.2 : 1.0,
        ),
        boxShadow: isUnassigned
            ? [const BoxShadow(color: Color(0x1FF2C181), blurRadius: 12, offset: Offset(0, 0))]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${item.lineTotal.toStringAsFixed(0)} $currency',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                key: Key('override-${item.id}'),
                onPressed: onOverride,
                visualDensity: VisualDensity.compact,
                tooltip: 'Weights',
                icon: Icon(
                  hasOverride ? Icons.tune : Icons.tune_outlined,
                  size: 20,
                  color: hasOverride ? AppTokens.primary : AppTokens.onDim,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < people.length; i++)
                _PersonChip(
                  key: Key('chip-${item.id}-${people[i].id}'),
                  person: people[i],
                  index: i,
                  selected: assignedIds.contains(people[i].id),
                  onTap: () => onToggle(people[i]),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PersonChip extends StatelessWidget {
  const _PersonChip({
    super.key,
    required this.person,
    required this.index,
    required this.selected,
    required this.onTap,
  });
  final Person person;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppTokens.personPalette[index % AppTokens.personPalette.length];
    final bg = selected ? color.withValues(alpha: 0.12) : Colors.transparent;
    final borderColor = selected ? color.withValues(alpha: 0.45) : AppTokens.outline;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(3, 3, 10, 3),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PersonAvatar(name: person.name, index: index, size: 22),
              const SizedBox(width: 6),
              Text(
                person.name,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppTokens.onSurface : AppTokens.onMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

  void _save() {
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
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Weights for ${widget.item.name}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Higher = pays a bigger share of this item.',
            style: TextStyle(color: AppTokens.onMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          for (final pid in widget.personIds)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Builder(
                    builder: (context) {
                      final p = widget.people.firstWhere((p) => p.id == pid);
                      final i = widget.people.indexOf(p);
                      return Row(
                        children: [
                          PersonAvatar(name: p.name, index: i, size: 28),
                          const SizedBox(width: 10),
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      );
                    },
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      key: Key('weight-${widget.item.id}-$pid'),
                      controller: _controllers[pid],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          PillButton(
            key: Key('weight-save-${widget.item.id}'),
            label: 'Save',
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
