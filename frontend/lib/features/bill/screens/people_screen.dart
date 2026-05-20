import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/ui/bill_stepper.dart';
import '../../../core/ui/bottom_action_bar.dart';
import '../../../core/ui/display_title.dart';
import '../../../core/ui/inline_hint.dart';
import '../../../core/ui/person_avatar.dart';
import '../../../core/ui/pill_button.dart';
import '../../../l10n/app_localizations.dart';
import '../model/person.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key, required this.onProceed});
  final ValueChanged<List<Person>> onProceed;

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final List<Person> _people = [];

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _addPerson() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _people.add(Person.create(name));
      _nameController.clear();
    });
    _nameFocus.requestFocus();
  }

  void _removeAt(int index) {
    setState(() => _people.removeAt(index));
  }

  bool get _canProceed => _people.length >= 2;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(toolbarHeight: 36),
      body: Column(
        children: [
          const BillStepper(step: 0),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                DisplayTitle.rich(
                  [
                    DisplayTitle.plain('Who’s '),
                    DisplayTitle.accent('splitting'),
                    DisplayTitle.plain('\nthis bill?'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Add at least two names. You can remove or rename them anytime.',
                  style: Theme.of(context).textTheme.bodyMedium!
                      .copyWith(color: AppTokens.onMuted, height: 1.4),
                ),
                const SizedBox(height: 20),
                // Existing people
                for (var i = 0; i < _people.length; i++) ...[
                  _NameRow(
                    person: _people[i],
                    index: i,
                    onRemove: () => _removeAt(i),
                  ),
                  const SizedBox(height: 8),
                ],
                // Add-person row (text field + add button)
                _AddPersonRow(
                  controller: _nameController,
                  focus: _nameFocus,
                  hint: l.addPersonHint,
                  index: _people.length,
                  onSubmit: _addPerson,
                ),
                if (!_canProceed) ...[
                  const SizedBox(height: 16),
                  InlineHint(
                    message: l.needAtLeastTwoPeople,
                    tone: HintTone.warn,
                  ),
                ],
              ],
            ),
          ),
          BottomActionBar(
            child: Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '${_people.length} ${_people.length == 1 ? "person" : "people"}',
                    style: const TextStyle(fontSize: 13, color: AppTokens.onMuted),
                  ),
                ),
                const SizedBox(height: 10),
                PillButton(
                  key: const Key('people-next-button'),
                  label: l.nextButton,
                  icon: Icons.arrow_forward,
                  iconAtEnd: true,
                  onPressed: _canProceed
                      ? () => widget.onProceed(List.unmodifiable(_people))
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

class _NameRow extends StatelessWidget {
  const _NameRow({required this.person, required this.index, required this.onRemove});
  final Person person;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border.all(color: AppTokens.outlineSoft),
      ),
      child: Row(
        children: [
          PersonAvatar(name: person.name, index: index),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              person.name,
              style: const TextStyle(fontSize: 16, color: AppTokens.onSurface),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            key: Key('remove-person-$index'),
            iconSize: 20,
            color: AppTokens.onDim,
            icon: const Icon(Icons.close),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _AddPersonRow extends StatelessWidget {
  const _AddPersonRow({
    required this.controller,
    required this.focus,
    required this.hint,
    required this.index,
    required this.onSubmit,
  });
  final TextEditingController controller;
  final FocusNode focus;
  final String hint;
  final int index;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border.all(color: AppTokens.outline, width: 1.5, style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppTokens.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: AppTokens.onPrimaryContainer, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          ElevatedButton(
            key: const Key('add-person-button'),
            onPressed: onSubmit,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: const StadiumBorder(),
              backgroundColor: AppTokens.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
