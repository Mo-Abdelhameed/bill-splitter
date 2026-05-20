import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../compute/charge_distribution.dart';
import '../compute/rounding.dart';
import '../compute/subtotals.dart';
import '../model/assignment.dart';
import '../model/item.dart';
import '../model/person.dart';

class TotalsScreen extends StatelessWidget {
  const TotalsScreen({
    super.key,
    required this.people,
    required this.items,
    required this.assignments,
    required this.taxAmount,
    required this.serviceAmount,
    required this.onStartNewBill,
  });

  final List<Person> people;
  final List<Item> items;
  final Map<String, Assignment> assignments;
  final num? taxAmount;
  final num? serviceAmount;
  final VoidCallback onStartNewBill;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    final subtotals = computeItemSubtotals(
      personIds: people.map((p) => p.id).toList(),
      items: items,
      assignments: assignments,
    );
    final taxShares = distributeCharge(charge: taxAmount, itemSubtotals: subtotals);
    final serviceShares = distributeCharge(charge: serviceAmount, itemSubtotals: subtotals);

    return Scaffold(
      appBar: AppBar(title: Text(l.totalsScreenTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: people.length,
                separatorBuilder: (_, _) => const Divider(height: 24),
                itemBuilder: (context, i) {
                  final p = people[i];
                  final subtotal = subtotals[p.id] ?? 0;
                  final tax = taxShares[p.id];
                  final service = serviceShares[p.id];
                  final finalTotal = roundUpEgp(
                    subtotal + (tax ?? 0) + (service ?? 0),
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      _row(
                        context,
                        keyTag: 'subtotal-${p.id}',
                        label: l.subtotalLabel,
                        amount: subtotal,
                      ),
                      if (tax != null)
                        _row(
                          context,
                          keyTag: 'tax-share-${p.id}',
                          label: l.taxLabel,
                          amount: tax,
                        ),
                      if (service != null)
                        _row(
                          context,
                          keyTag: 'service-share-${p.id}',
                          label: l.serviceLabel,
                          amount: service,
                        ),
                      const SizedBox(height: 4),
                      _row(
                        context,
                        keyTag: 'final-${p.id}',
                        label: l.finalLabel,
                        amount: finalTotal,
                        emphasize: true,
                      ),
                    ],
                  );
                },
              ),
            ),
            ElevatedButton(
              key: const Key('start-new-bill-button'),
              onPressed: onStartNewBill,
              child: Text(l.startNewBillButton),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String keyTag,
    required String label,
    required num amount,
    bool emphasize = false,
  }) {
    final l = AppLocalizations.of(context)!;
    final style = emphasize
        ? Theme.of(context).textTheme.titleSmall
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      key: Key(keyTag),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(_fmt(amount), style: style),
          const SizedBox(width: 4),
          Text(l.currencyEgp, style: style),
        ],
      ),
    );
  }

  String _fmt(num amount) {
    if (amount is int) return amount.toString();
    final asDouble = amount.toDouble();
    if (asDouble == asDouble.truncateToDouble()) {
      return asDouble.toInt().toString();
    }
    return asDouble.toStringAsFixed(2);
  }
}
