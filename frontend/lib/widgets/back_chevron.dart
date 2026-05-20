import 'package:flutter/material.dart';

import 'package:bill_split/theme.dart';

/// Slim leading back-chevron row used above [FlowStepper] on every screen
/// after the People (root) screen. Renders nothing on the root so the layout
/// stays balanced. Pops the navigator on tap.
class BackChevronBar extends StatelessWidget {
  const BackChevronBar({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Navigator.canPop(context)) {
      // Reserve the same vertical space as the back button so screens align.
      return const SizedBox(height: 44);
    }
    final tokens = Theme.of(context).tokens;
    return SizedBox(
      height: 44,
      child: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: tokens.onSurface,
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
    );
  }
}
