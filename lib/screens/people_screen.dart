import 'package:flutter/material.dart';

import 'package:bill_split/state/bill_state.dart';

/// First screen of the bill-split flow.
///
/// AC-1..AC-7 of STORY-001. Duplicate-name detection deferred to Continue tap
/// per the 2026-05-19 amendment.
class PeopleScreen extends StatefulWidget {
  final BillState billState;
  final VoidCallback onContinue;

  const PeopleScreen({
    super.key,
    required this.billState,
    required this.onContinue,
  });

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  // Index 0 is the original, non-removable field. Indices >0 are added via "+".
  final List<TextEditingController> _controllers = <TextEditingController>[
    TextEditingController(),
  ];

  /// Lowercased+trimmed names that the most recent Continue tap flagged as
  /// duplicates. Drives the inline "Duplicate name" indicator. Cleared on any
  /// text edit so typing doesn't show stale errors.
  Set<String> _duplicateNamesLower = const <String>{};

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addField() {
    setState(() {
      _controllers.add(TextEditingController());
      _duplicateNamesLower = const <String>{};
    });
  }

  void _removeField(int index) {
    setState(() {
      _controllers.removeAt(index).dispose();
      _duplicateNamesLower = const <String>{};
    });
  }

  List<String> get _trimmedNames =>
      _controllers.map((c) => c.text.trim()).toList(growable: false);

  List<String> get _nonEmptyNames =>
      _trimmedNames.where((n) => n.isNotEmpty).toList(growable: false);

  bool get _canContinue => _nonEmptyNames.length >= 2;

  Set<String> _computeDuplicateLowercaseNames() {
    final counts = <String, int>{};
    for (final name in _nonEmptyNames) {
      final key = name.toLowerCase();
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts.entries
        .where((MapEntry<String, int> e) => e.value > 1)
        .map((MapEntry<String, int> e) => e.key)
        .toSet();
  }

  void _onContinue() {
    final duplicates = _computeDuplicateLowercaseNames();
    if (duplicates.isNotEmpty) {
      setState(() => _duplicateNamesLower = duplicates);
      return;
    }
    widget.billState.people = _nonEmptyNames;
    widget.onContinue();
  }

  bool _isDuplicateField(TextEditingController controller) {
    if (_duplicateNamesLower.isEmpty) return false;
    final value = controller.text.trim();
    if (value.isEmpty) return false;
    return _duplicateNamesLower.contains(value.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Who's splitting?")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ..._buildNameFields(),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _addField,
                  icon: const Icon(Icons.add),
                  label: const Text('Add another'),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _canContinue ? _onContinue : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildNameFields() {
    final widgets = <Widget>[];
    for (var i = 0; i < _controllers.length; i++) {
      final controller = _controllers[i];
      final isOriginal = i == 0;
      final showDuplicate = _isDuplicateField(controller);

      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'Enter name',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    setState(() {
                      // Edit clears any stale duplicate flags so the indicator
                      // doesn't linger while the user is fixing the issue.
                      _duplicateNamesLower = const <String>{};
                    });
                  },
                ),
              ),
              if (!isOriginal)
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Remove',
                  onPressed: () => _removeField(i),
                ),
            ],
          ),
        ),
      );
      if (showDuplicate) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              'Duplicate name',
              style: TextStyle(color: Colors.red, fontSize: 14),
            ),
          ),
        );
      }
    }
    return widgets;
  }
}
