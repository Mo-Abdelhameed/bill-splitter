import 'package:flutter/material.dart';

import 'package:bill_split/theme.dart';

/// Sticky bottom action area. Used by every flow screen so the divider,
/// padding, and surface treatment stay consistent.
class BottomActionBar extends StatelessWidget {
  final Widget child;
  final String? caption;

  const BottomActionBar({super.key, required this.child, this.caption});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: tokens.bg,
        border: Border(top: BorderSide(color: tokens.outlineSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (caption != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                caption!,
                style: TextStyle(color: tokens.onMuted, fontSize: 13),
              ),
            ),
          child,
        ],
      ),
    );
  }
}
