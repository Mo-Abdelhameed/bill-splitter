import 'package:flutter/material.dart';

import 'package:bill_split/state/bill_item.dart';
import 'package:bill_split/state/bill_state.dart';
import 'package:bill_split/theme.dart';
import 'package:bill_split/widgets/back_chevron.dart';
import 'package:bill_split/widgets/bottom_action_bar.dart';
import 'package:bill_split/widgets/flow_stepper.dart';

/// Assigns people to items. Two interaction modes coexist (FR-005):
///   - Drag a chip from the people column onto an item row (DragTarget).
///   - Tap an item row to open a modal with per-person checkboxes.
/// Long-pressing an assignee chip on an item opens a weight popover (FR-007a).
class AssignmentScreen extends StatefulWidget {
  final BillState billState;
  final VoidCallback onContinue;

  const AssignmentScreen({
    super.key,
    required this.billState,
    required this.onContinue,
  });

  @override
  State<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends State<AssignmentScreen> {
  // Indexed palette — color per person based on insertion order.
  static const List<Color> _palette = <Color>[
    Color(0xFFC7693A),
    Color(0xFF7A8C5C),
    Color(0xFFB25E73),
    Color(0xFFC39A3A),
    Color(0xFF7B6FB0),
    Color(0xFF5E7A85),
  ];

  Color _colorFor(String name) {
    final idx = widget.billState.people.indexOf(name);
    if (idx < 0) return _palette[0];
    return _palette[idx % _palette.length];
  }

  Map<String, Map<String, double>> get _assignments =>
      widget.billState.assignments;

  void _assign(String itemId, String person, {double weight = 1}) {
    final map = _assignments.putIfAbsent(itemId, () => <String, double>{});
    map[person] = weight;
  }

  void _unassign(String itemId, String person) {
    _assignments[itemId]?.remove(person);
  }

  bool _isAssigned(String itemId, String person) =>
      _assignments[itemId]?.containsKey(person) ?? false;

  int get _unassignedCount {
    int n = 0;
    for (final item in widget.billState.items) {
      final assignees = _assignments[item.id];
      if (assignees == null || assignees.isEmpty) n++;
    }
    return n;
  }

  bool get _canContinue {
    if (widget.billState.items.isEmpty) return false;
    return _unassignedCount == 0;
  }

  Future<void> _openAssignModal(BillItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            final tokens = Theme.of(ctx).tokens;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: Text(
                        'Who had ${item.name}?',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                              color: tokens.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final String name in widget.billState.people)
                      CheckboxListTile(
                        key: ValueKey<String>('assign-checkbox-$name'),
                        value: _isAssigned(item.id, name),
                        secondary: _Avatar(name: name, color: _colorFor(name)),
                        title: Text(name),
                        onChanged: (bool? v) {
                          setModalState(() {
                            if (v == true) {
                              _assign(item.id, name);
                            } else {
                              _unassign(item.id, name);
                            }
                          });
                        },
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _openWeightEditor(String itemId, String person) async {
    final double? newWeight = await showDialog<double>(
      context: context,
      builder: (BuildContext ctx) => _WeightDialog(
        itemId: itemId,
        person: person,
        initial: _assignments[itemId]?[person] ?? 1.0,
      ),
    );
    if (newWeight != null && newWeight > 0) {
      _assignments[itemId]?[person] = newWeight;
    }
    if (mounted) setState(() {});
  }

  void _onContinue() {
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const BackChevronBar(),
            const FlowStepper(step: 3),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        const TextSpan(text: 'Drag '),
                        TextSpan(
                          text: 'names',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: tokens.primary,
                          ),
                        ),
                        const TextSpan(text: ' onto items.'),
                      ],
                    ),
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to add too. Long-press a chip to adjust split weight.',
                    style:
                        TextStyle(color: tokens.onMuted, fontSize: 13, height: 1.35),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildTwoColumns(tokens)),
            BottomActionBar(
              caption: _unassignedCount > 0
                  ? '$_unassignedCount item${_unassignedCount == 1 ? '' : 's'} still need someone'
                  : null,
              child: ElevatedButton(
                onPressed: _canContinue ? _onContinue : null,
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTwoColumns(BillSplitTokens tokens) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // LEFT: people column
          Container(
            width: 92,
            decoration: BoxDecoration(
              color: tokens.surfaceLow,
              border: Border.all(color: tokens.outlineSoft),
              borderRadius: BorderRadius.circular(tokens.radius),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              children: <Widget>[
                Text(
                  'PEOPLE',
                  style: TextStyle(
                    color: tokens.onDim,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: <Widget>[
                      for (final name in widget.billState.people)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: _DraggablePerson(
                            name: name,
                            color: _colorFor(name),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // RIGHT: items column
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 12),
              itemCount: widget.billState.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (BuildContext context, int i) {
                final item = widget.billState.items[i];
                return _buildItemRow(item, tokens);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(BillItem item, BillSplitTokens tokens) {
    final assignees = _assignments[item.id] ?? const <String, double>{};
    final unassigned = assignees.isEmpty;
    return DragTarget<String>(
      onAcceptWithDetails: (DragTargetDetails<String> d) {
        setState(() => _assign(item.id, d.data));
      },
      builder: (BuildContext ctx, List<String?> candidates, List<dynamic> rejects) {
        final hovering = candidates.isNotEmpty;
        return Container(
          key: ValueKey<String>('item-row-${item.id}'),
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border.all(
              color: hovering
                  ? tokens.primary
                  : (unassigned ? tokens.warnBorder : tokens.outlineSoft),
              width: hovering ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: unassigned
                ? <BoxShadow>[
                    BoxShadow(
                      color: tokens.warnBorder.withValues(alpha: 0.25),
                      blurRadius: 0,
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openAssignModal(item),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                        ),
                        Text(
                          item.price.toStringAsFixed(2),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: tokens.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (unassigned)
                      Row(
                        key: ValueKey<String>('unassigned-indicator-${item.id}'),
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: tokens.outline,
                                style: BorderStyle.solid,
                              ),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              'Drop a name here',
                              style:
                                  TextStyle(color: tokens.onDim, fontSize: 12),
                            ),
                          ),
                        ],
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          for (final entry in assignees.entries)
                            _buildAssigneeChip(
                              itemId: item.id,
                              person: entry.key,
                              weight: entry.value,
                              tokens: tokens,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssigneeChip({
    required String itemId,
    required String person,
    required double weight,
    required BillSplitTokens tokens,
  }) {
    final color = _colorFor(person);
    final label = weight == 1.0 ? person : '$person ×${_fmtWeight(weight)}';
    return GestureDetector(
      key: ValueKey<String>('assignee-chip-$itemId-$person'),
      onLongPress: () => _openWeightEditor(itemId, person),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _Avatar(name: person, color: color, size: 22),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _unassign(itemId, person)),
              child: Icon(Icons.close, size: 14, color: tokens.onDim),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtWeight(double w) =>
      w == w.truncate() ? w.toInt().toString() : w.toString();
}

class _Avatar extends StatelessWidget {
  final String name;
  final Color color;
  final double size;
  const _Avatar({required this.name, required this.color, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final hasName = name.isNotEmpty;
    final initial = hasName ? name.characters.first.toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}

class _DraggablePerson extends StatelessWidget {
  final String name;
  final Color color;
  const _DraggablePerson({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).tokens;
    final firstName = name.split(' ').first;
    return Draggable<String>(
      key: ValueKey<String>('person-draggable-$name'),
      data: name,
      feedback: Material(
        color: Colors.transparent,
        child: _Avatar(name: name, color: color, size: 48),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _PersonChipColumn(name: firstName, color: color, tokens: tokens),
      ),
      child: _PersonChipColumn(name: firstName, color: color, tokens: tokens),
    );
  }
}

class _PersonChipColumn extends StatelessWidget {
  final String name;
  final Color color;
  final BillSplitTokens tokens;
  const _PersonChipColumn({
    required this.name,
    required this.color,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _Avatar(name: name, color: color, size: 44),
        const SizedBox(height: 4),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: tokens.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

/// Stateful dialog for the per-assignee weight popover. Owns a
/// [TextEditingController] whose lifecycle is bound to the dialog's State so
/// it is disposed after the dialog is fully torn down — not before.
class _WeightDialog extends StatefulWidget {
  final String itemId;
  final String person;
  final double initial;

  const _WeightDialog({
    required this.itemId,
    required this.person,
    required this.initial,
  });

  @override
  State<_WeightDialog> createState() => _WeightDialogState();
}

class _WeightDialogState extends State<_WeightDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial.toString());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Weight for ${widget.person}'),
      content: TextField(
        key: ValueKey<String>('weight-input-${widget.itemId}-${widget.person}'),
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Weight'),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final parsed = double.tryParse(_controller.text);
            Navigator.of(context).pop(parsed);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
