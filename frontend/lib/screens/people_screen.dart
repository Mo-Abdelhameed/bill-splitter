import 'package:flutter/material.dart';

import 'package:bill_split/state/bill_state.dart';
import 'package:bill_split/theme.dart';
import 'package:bill_split/widgets/back_chevron.dart';
import 'package:bill_split/widgets/bottom_action_bar.dart';
import 'package:bill_split/widgets/flow_stepper.dart';

/// First screen of the bill-split flow.
///
/// FR-001 (entry / add / remove) + FR-008 (commit + navigate) + FR-011
/// (Continue gating) + FR-017 (duplicate detection at Continue time).
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
  final List<FocusNode> _focusNodes = <FocusNode>[FocusNode()];

  /// Lowercased+trimmed names that the most recent Continue tap flagged as
  /// duplicates. Drives the inline "Duplicate name" indicator. Cleared on any
  /// text edit so typing doesn't show stale errors.
  Set<String> _duplicateNamesLower = const <String>{};

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _addField() {
    setState(() {
      _controllers.add(TextEditingController());
      _focusNodes.add(FocusNode());
      _duplicateNamesLower = const <String>{};
    });
  }

  void _removeField(int index) {
    setState(() {
      _controllers.removeAt(index).dispose();
      _focusNodes.removeAt(index).dispose();
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
    final theme = Theme.of(context);
    final tokens = theme.tokens;
    final validCount = _nonEmptyNames.length;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const BackChevronBar(),
            const FlowStepper(step: 0),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          const TextSpan(text: "Who's "),
                          TextSpan(
                            text: 'splitting',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: tokens.primary,
                            ),
                          ),
                          const TextSpan(text: '\nthis bill?'),
                        ],
                      ),
                      style: theme.textTheme.displayMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add at least two names. You can rearrange or remove them anytime.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: tokens.onMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ..._buildNameRows(tokens),
                    const SizedBox(height: 10),
                    _buildAddRow(tokens),
                    if (_duplicateNamesLower.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _DuplicateHint(tokens: tokens),
                      ),
                  ],
                ),
              ),
            ),
            BottomActionBar(
              caption: '$validCount ${validCount == 1 ? 'person' : 'people'}',
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

  List<Widget> _buildNameRows(BillSplitTokens tokens) {
    final rows = <Widget>[];
    for (int i = 0; i < _controllers.length; i++) {
      final controller = _controllers[i];
      final focusNode = _focusNodes[i];
      final isOriginal = i == 0;
      final isDuplicate = _isDuplicateField(controller);

      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
          child: _NameRow(
            controller: controller,
            focusNode: focusNode,
            index: i,
            isDuplicate: isDuplicate,
            tokens: tokens,
            onChanged: () {
              setState(() {
                _duplicateNamesLower = const <String>{};
              });
            },
            onRemove: isOriginal ? null : () => _removeField(i),
          ),
        ),
      );
      if (isDuplicate) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: Text(
              'Duplicate name',
              style: TextStyle(color: tokens.danger, fontSize: 13),
            ),
          ),
        );
      }
    }
    return rows;
  }

  Widget _buildAddRow(BillSplitTokens tokens) {
    return InkWell(
      onTap: _addField,
      borderRadius: BorderRadius.circular(tokens.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: tokens.outline, width: 1.5),
          borderRadius: BorderRadius.circular(tokens.radius),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: tokens.primaryContainer,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.add, color: tokens.onPrimaryContainer, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Add another',
              style: TextStyle(
                color: tokens.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NameRow extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int index;
  final bool isDuplicate;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  final BillSplitTokens tokens;

  const _NameRow({
    required this.controller,
    required this.focusNode,
    required this.index,
    required this.isDuplicate,
    required this.onChanged,
    required this.onRemove,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    // Border reacts to focus via [AnimatedBuilder] listening to the
    // FocusNode — this scopes the rebuild to JUST this row, not the whole
    // screen, so tapping a different row's TextField transitions focus
    // without forcing a global rebuild (which was making the OS keyboard
    // briefly dismiss and re-pop).
    return AnimatedBuilder(
      animation: focusNode,
      builder: (BuildContext context, Widget? child) {
        final isFocused = focusNode.hasFocus;
        final borderColor = isDuplicate
            ? tokens.danger
            : isFocused
                ? tokens.primary
                : tokens.outlineSoft;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(tokens.radius),
            boxShadow: isFocused
                ? <BoxShadow>[
                    BoxShadow(
                      color: tokens.primary.withValues(alpha: 0.1),
                      blurRadius: 0,
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
          child: child,
        );
      },
      child: Row(
        children: <Widget>[
          _PersonAvatar(name: controller.text.trim(), index: index, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              // Auto-capitalize the first letter of each word so names like
              // "mo" → "Mo" on the keyboard layer.
              textCapitalization: TextCapitalization.words,
              // `next` keeps the keyboard up when the user moves focus via
              // the return key, instead of dismissing it ("done" default).
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: 'Enter name',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isCollapsed: true,
                hintStyle: TextStyle(color: tokens.onDim),
              ),
              style: TextStyle(fontSize: 16, color: tokens.onSurface),
              onChanged: (_) => onChanged(),
            ),
          ),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Remove',
              color: tokens.onDim,
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

/// Initial-bubble avatar. Color is derived from the row index (no `Person`
/// model in v1; the People screen tracks plain strings). When the field is
/// empty the avatar is a neutral placeholder.
class _PersonAvatar extends StatelessWidget {
  static const List<Color> _palette = <Color>[
    Color(0xFFC7693A),
    Color(0xFF7A8C5C),
    Color(0xFFB25E73),
    Color(0xFFC39A3A),
    Color(0xFF7B6FB0),
    Color(0xFF5E7A85),
  ];

  final String name;
  final int index;
  final double size;

  const _PersonAvatar({
    required this.name,
    required this.index,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).tokens;
    final hasName = name.isNotEmpty;
    final color = hasName ? _palette[index % _palette.length] : tokens.surfaceLow;
    final initial = hasName ? name.characters.first.toUpperCase() : '';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: hasName ? null : Border.all(color: tokens.outline),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: hasName ? Colors.white : tokens.onDim,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.42,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _DuplicateHint extends StatelessWidget {
  final BillSplitTokens tokens;
  const _DuplicateHint({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.warnSurface,
        border: Border.all(color: tokens.warnBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, color: tokens.warn, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Two names match — rename to disambiguate.',
              style: TextStyle(color: tokens.warn, fontSize: 13.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

