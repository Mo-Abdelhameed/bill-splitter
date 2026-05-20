import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'locale.dart';

/// AppBar action that toggles between English and Arabic — FR-019.
///
/// Reads/writes the shared [LocaleController]; the controller persists the
/// choice via shared_preferences (SC-006).
class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key, required this.controller});
  final LocaleController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return TextButton(
      key: const Key('language-toggle-button'),
      onPressed: controller.toggle,
      child: Text(
        l.languageButton,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
    );
  }
}
