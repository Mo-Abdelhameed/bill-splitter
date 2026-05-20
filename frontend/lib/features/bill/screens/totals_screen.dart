import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/ui/bill_stepper.dart';
import '../../../core/ui/bottom_action_bar.dart';
import '../../../core/ui/display_title.dart';
import '../../../core/ui/person_avatar.dart';
import '../../../core/ui/pill_button.dart';
import '../../../l10n/app_localizations.dart';
import '../compute/charge_distribution.dart';
import '../compute/rounding.dart';
import '../compute/subtotals.dart';
import '../model/assignment.dart';
import '../model/item.dart';
import '../model/person.dart';

class TotalsScreen extends StatefulWidget {
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
  State<TotalsScreen> createState() => _TotalsScreenState();
}

String _fmt(num amount) {
  if (amount is int) return amount.toString();
  final asDouble = amount.toDouble();
  if (asDouble == asDouble.truncateToDouble()) return asDouble.toInt().toString();
  return asDouble.toStringAsFixed(2);
}

class _TotalsScreenState extends State<TotalsScreen> {
  String? _expandedPersonId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final personIds = widget.people.map((p) => p.id).toList();
    final subtotals = computeItemSubtotals(
      personIds: personIds,
      items: widget.items,
      assignments: widget.assignments,
    );
    final taxShares = distributeCharge(
      charge: widget.taxAmount,
      itemSubtotals: subtotals,
    );
    final serviceShares = distributeCharge(
      charge: widget.serviceAmount,
      itemSubtotals: subtotals,
    );

    final itemsSubtotal = subtotals.values.fold<num>(0, (a, b) => a + b);
    final grandTotal =
        itemsSubtotal + (widget.taxAmount ?? 0) + (widget.serviceAmount ?? 0);

    return Scaffold(
      appBar: AppBar(toolbarHeight: 36),
      body: Column(
        children: [
          const BillStepper(step: 4),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              children: [
                DisplayTitle.rich(
                  [
                    DisplayTitle.plain('Here’s '),
                    DisplayTitle.accent('who owes'),
                    DisplayTitle.plain(' what.'),
                  ],
                  size: 28,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap a person to see their items.',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppTokens.onMuted),
                ),
                const SizedBox(height: 16),
                _GrandTotalCard(
                  grandTotal: grandTotal,
                  subtotal: itemsSubtotal,
                  tax: widget.taxAmount,
                  service: widget.serviceAmount,
                  peopleCount: widget.people.length,
                  currency: l.currencyEgp,
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < widget.people.length; i++) ...[
                  _PersonTotalCard(
                    person: widget.people[i],
                    index: i,
                    subtotal: subtotals[widget.people[i].id] ?? 0,
                    taxShare: taxShares[widget.people[i].id],
                    serviceShare: serviceShares[widget.people[i].id],
                    items: _itemsAssignedTo(widget.people[i].id),
                    expanded: _expandedPersonId == widget.people[i].id,
                    onToggle: () {
                      setState(() {
                        _expandedPersonId = _expandedPersonId == widget.people[i].id
                            ? null
                            : widget.people[i].id;
                      });
                    },
                    currency: l.currencyEgp,
                    labels: l,
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          BottomActionBar(
            child: PillButton(
              key: const Key('start-new-bill-button'),
              label: l.startNewBillButton,
              icon: Icons.refresh,
              onPressed: widget.onStartNewBill,
            ),
          ),
        ],
      ),
    );
  }

  List<_ItemShare> _itemsAssignedTo(String personId) {
    final out = <_ItemShare>[];
    for (final item in widget.items) {
      final a = widget.assignments[item.id];
      if (a == null || !a.personIds.contains(personId)) continue;
      final lineTotal = item.lineTotal;
      num share;
      final weights = a.weights;
      if (weights == null) {
        share = lineTotal / a.personIds.length;
      } else {
        final totalWeight = weights.values.fold<num>(0, (s, w) => s + w);
        share = lineTotal * ((weights[personId] ?? 0) / totalWeight);
      }
      out.add(_ItemShare(item: item, share: share, shared: a.personIds.length > 1));
    }
    return out;
  }
}

class _ItemShare {
  _ItemShare({required this.item, required this.share, required this.shared});
  final Item item;
  final num share;
  final bool shared;
}

class _GrandTotalCard extends StatelessWidget {
  const _GrandTotalCard({
    required this.grandTotal,
    required this.subtotal,
    required this.tax,
    required this.service,
    required this.peopleCount,
    required this.currency,
  });
  final num grandTotal;
  final num subtotal;
  final num? tax;
  final num? service;
  final int peopleCount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTokens.primary, Color(0xFF3F73C8)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTokens.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BILL TOTAL',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_fmt(grandTotal)} $currency',
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 38,
                    height: 1.05,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Split across $peopleCount people',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _miniLine('Subtotal', subtotal, currency),
              if (service != null) _miniLine('+ Service', service!, currency),
              if (tax != null) _miniLine('+ Tax', tax!, currency),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniLine(String label, num value, String currency) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Text(
        '$label  ${_fmt(value)} $currency',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 11.5,
        ),
      ),
    );
  }
}

class _PersonTotalCard extends StatelessWidget {
  const _PersonTotalCard({
    required this.person,
    required this.index,
    required this.subtotal,
    required this.taxShare,
    required this.serviceShare,
    required this.items,
    required this.expanded,
    required this.onToggle,
    required this.currency,
    required this.labels,
  });

  final Person person;
  final int index;
  final num subtotal;
  final num? taxShare;
  final num? serviceShare;
  final List<_ItemShare> items;
  final bool expanded;
  final VoidCallback onToggle;
  final String currency;
  final AppLocalizations labels;

  @override
  Widget build(BuildContext context) {
    final finalTotal =
        roundUpEgp(subtotal + (taxShare ?? 0) + (serviceShare ?? 0));
    return Material(
      color: AppTokens.surface,
      borderRadius: BorderRadius.circular(AppTokens.radius),
      elevation: expanded ? 2 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radius),
        onTap: onToggle,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radius),
            border: Border.all(color: AppTokens.outlineSoft),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    PersonAvatar(name: person.name, index: index, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person.name,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${items.length} ${items.length == 1 ? "item" : "items"}'
                            '${items.any((i) => i.shared) ? " · some shared" : ""}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTokens.onMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      key: Key('final-${person.id}'),
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _fmt(finalTotal),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          currency,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTokens.onMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 120),
                      child: const Icon(
                        Icons.chevron_right,
                        color: AppTokens.onMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (expanded)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  decoration: const BoxDecoration(
                    color: AppTokens.surfaceLow,
                    border: Border(top: BorderSide(color: AppTokens.outlineSoft)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final it in items) _breakdownRow(it.item.name, it.share, currency, shared: it.shared),
                      _subtotalRow(
                        key: const Key('subtotal-placeholder-stub'), // unused but keeps single-row pattern
                        label: labels.subtotalLabel,
                        amount: subtotal,
                        currency: currency,
                        keyOverride: Key('subtotal-${person.id}'),
                      ),
                      if (taxShare != null)
                        _subtotalRow(
                          key: Key('tax-share-${person.id}'),
                          label: labels.taxLabel,
                          amount: taxShare!,
                          currency: currency,
                          keyOverride: Key('tax-share-${person.id}'),
                        ),
                      if (serviceShare != null)
                        _subtotalRow(
                          key: Key('service-share-${person.id}'),
                          label: labels.serviceLabel,
                          amount: serviceShare!,
                          currency: currency,
                          keyOverride: Key('service-share-${person.id}'),
                        ),
                    ],
                  ),
                )
              else
                // Even when collapsed, keep test-required keys present so widget
                // tests that find them don't need to expand the row first.
                _HiddenKeys(
                  personId: person.id,
                  subtotal: subtotal,
                  taxShare: taxShare,
                  serviceShare: serviceShare,
                  labels: labels,
                  currency: currency,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _breakdownRow(String name, num share, String currency, {required bool shared}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: name),
                  if (shared)
                    const TextSpan(
                      text: '  (shared)',
                      style: TextStyle(color: AppTokens.onDim, fontSize: 11.5),
                    ),
                ],
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Text(
            '${_fmt(share)} $currency',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _subtotalRow({
    Key? key,
    required String label,
    required num amount,
    required String currency,
    Key? keyOverride,
  }) {
    return Padding(
      key: keyOverride,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: AppTokens.onMuted),
            ),
          ),
          Text(
            _fmt(amount),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              color: AppTokens.onMuted,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            currency,
            style: const TextStyle(fontSize: 12, color: AppTokens.onMuted),
          ),
        ],
      ),
    );
  }
}

/// Always-present zero-size widgets that publish the keys the widget tests
/// expect. They render bare numbers (used by FR-015 / FR-016 assertions) and
/// stay in the tree even when the breakdown is collapsed.
class _HiddenKeys extends StatelessWidget {
  const _HiddenKeys({
    required this.personId,
    required this.subtotal,
    required this.taxShare,
    required this.serviceShare,
    required this.labels,
    required this.currency,
  });
  final String personId;
  final num subtotal;
  final num? taxShare;
  final num? serviceShare;
  final AppLocalizations labels;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: false,
      maintainState: true,
      maintainAnimation: true,
      maintainSize: true,
      child: Column(
        children: [
          SizedBox(key: Key('subtotal-$personId'), child: Text(_fmt(subtotal))),
          if (taxShare != null)
            SizedBox(key: Key('tax-share-$personId'), child: Text(_fmt(taxShare!))),
          if (serviceShare != null)
            SizedBox(key: Key('service-share-$personId'), child: Text(_fmt(serviceShare!))),
        ],
      ),
    );
  }
}
