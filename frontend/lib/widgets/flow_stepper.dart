import 'package:flutter/material.dart';

import 'package:bill_split/theme.dart';

/// Top-of-screen progress indicator for the 5-screen split flow.
///
/// Matches the design at `specs/001-bill-split-flow/ui/`. The active step is
/// shown as a filled blue circle with the step number; completed steps show
/// a check; future steps are hollow with a hairline outline. The active
/// step's label is rendered next to its dot; the inactive ones collapse.
class FlowStepper extends StatelessWidget {
  /// Zero-indexed active step (0 = People, 4 = Totals).
  final int step;

  /// Labels shown for the active step; positional indexes match `step`.
  static const List<String> labels = <String>[
    'People',
    'Receipt',
    'Items',
    'Split',
    'Totals',
  ];

  const FlowStepper({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < labels.length; i++) ...<Widget>[
            _StepDot(
              index: i,
              label: labels[i],
              isActive: i == step,
              isDone: i < step,
              tokens: tokens,
            ),
            if (i < labels.length - 1)
              Expanded(
                child: Container(
                  height: 1.5,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  color: i < step
                      ? tokens.primary
                      : tokens.outline.withValues(alpha: 0.6),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int index;
  final String label;
  final bool isActive;
  final bool isDone;
  final BillSplitTokens tokens;

  const _StepDot({
    required this.index,
    required this.label,
    required this.isActive,
    required this.isDone,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final double size = isActive ? 22 : 18;
    final Color fill = isDone || isActive ? tokens.primary : Colors.transparent;
    final Widget? inner = isDone
        ? const Icon(Icons.check, size: 14, color: Colors.white)
        : isActive
            ? Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              )
            : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: isActive || isDone
                ? null
                : Border.all(color: tokens.outline, width: 1.5),
          ),
          child: inner,
        ),
        if (isActive)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: tokens.onSurface,
              ),
            ),
          ),
      ],
    );
  }
}
