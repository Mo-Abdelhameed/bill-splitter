import 'package:flutter/material.dart';

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
  final List<Person> _people = [];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addPerson() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _people.add(Person.create(name));
      _nameController.clear();
    });
  }

  void _removeAt(int index) {
    setState(() => _people.removeAt(index));
  }

  bool get _canProceed => _people.length >= 2;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.peopleScreenTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(hintText: l.addPersonHint),
                    onSubmitted: (_) => _addPerson(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  key: const Key('add-person-button'),
                  onPressed: _addPerson,
                  child: Text(l.addPersonButton),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _people.length,
                itemBuilder: (context, i) {
                  final p = _people[i];
                  return ListTile(
                    title: Text(p.name),
                    trailing: IconButton(
                      key: Key('remove-person-$i'),
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeAt(i),
                    ),
                  );
                },
              ),
            ),
            if (!_canProceed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l.needAtLeastTwoPeople,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ElevatedButton(
              key: const Key('people-next-button'),
              onPressed: _canProceed
                  ? () => widget.onProceed(List.unmodifiable(_people))
                  : null,
              child: Text(l.nextButton),
            ),
          ],
        ),
      ),
    );
  }
}
