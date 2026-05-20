import 'package:flutter/material.dart';

import 'package:bill_split/state/bill_item.dart';
import 'package:bill_split/state/bill_state.dart';
import 'package:bill_split/theme.dart';
import 'package:bill_split/widgets/back_chevron.dart';
import 'package:bill_split/widgets/flow_stepper.dart';

/// Terminal screen of the split flow — shows each person's total alongside
/// their item breakdown. Math lives in [_computeTotals] so it can be reasoned
/// about and tested separately from the layout.
class TotalsScreen extends StatefulWidget {
  final BillState billState;

  const TotalsScreen({super.key, required this.billState});

  @override
  State<TotalsScreen> createState() => _TotalsScreenState();
}

class _TotalsScreenState extends State<TotalsScreen> {
  static const List<Color> _palette = <Color>[
    Color(0xFFC7693A),
    Color(0xFF7A8C5C),
    Color(0xFFB25E73),
    Color(0xFFC39A3A),
    Color(0xFF7B6FB0),
    Color(0xFF5E7A85),
  ];

  /// Which person card (if any) is currently expanded to show the breakdown.
  String? _expanded;

  Color _colorFor(String name) {
    final idx = widget.billState.people.indexOf(name);
    if (idx < 0) return _palette[0];
    return _palette[idx % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;
    final result = _computeTotals(widget.billState);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const BackChevronBar(),
            const FlowStepper(step: 4),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: <Widget>[
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        const TextSpan(text: "Here's "),
                        TextSpan(
                          text: 'who owes',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: tokens.primary,
                          ),
                        ),
                        const TextSpan(text: ' what.'),
                      ],
                    ),
                    style: theme.textTheme.displaySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap a person to see their items.',
                    style:
                        TextStyle(color: tokens.onMuted, fontSize: 13.5),
                  ),
                  const SizedBox(height: 16),
                  _GrandTotalCard(result: result, tokens: tokens),
                  const SizedBox(height: 16),
                  for (final name in widget.billState.people)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PersonCard(
                        name: name,
                        color: _colorFor(name),
                        totals: result.perPerson[name] ?? _emptyTotals(),
                        expanded: _expanded == name,
                        onTap: () => setState(() {
                          _expanded = _expanded == name ? null : name;
                        }),
                        tokens: tokens,
                      ),
                    ),
                  if (result.residual.abs() > 0.0001)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: tokens.surfaceLow,
                        border: Border.all(color: tokens.outlineSoft),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            'Rounding',
                            style: TextStyle(
                              color: tokens.onMuted,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            key: const ValueKey<String>('rounding-residual'),
                            result.residual.toStringAsFixed(2),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _PersonTotals _emptyTotals() => const _PersonTotals(
        itemLines: <_Line>[],
        itemsSubtotal: 0,
        taxShare: 0,
        serviceShare: 0,
        total: 0,
      );
}

class _GrandTotalCard extends StatelessWidget {
  final _TotalsResult result;
  final BillSplitTokens tokens;
  const _GrandTotalCard({required this.result, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: tokens.primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tokens.primary.withValues(alpha: 0.22),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'BILL TOTAL',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      key: const ValueKey<String>('grand-total'),
                      result.billTotal.toStringAsFixed(2),
                      style: theme.textTheme.displayMedium?.copyWith(
                        color: Colors.white,
                        fontSize: 38,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    'Subtotal ${result.itemsTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11.5,
                    ),
                  ),
                  if (result.serviceAdded > 0)
                    Text(
                      '+ Service ${result.serviceAdded.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11.5,
                      ),
                    ),
                  if (result.taxAdded > 0)
                    Text(
                      '+ VAT ${result.taxAdded.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11.5,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final String name;
  final Color color;
  final _PersonTotals totals;
  final bool expanded;
  final VoidCallback onTap;
  final BillSplitTokens tokens;

  const _PersonCard({
    required this.name,
    required this.color,
    required this.totals,
    required this.expanded,
    required this.onTap,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tokens.surface,
      borderRadius: BorderRadius.circular(tokens.radius),
      child: InkWell(
        key: ValueKey<String>('person-card-$name'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radius),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: tokens.outlineSoft),
            borderRadius: BorderRadius.circular(tokens.radius),
            boxShadow: expanded
                ? <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Row(
                  children: <Widget>[
                    _PersonAvatar(name: name, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${totals.itemLines.length} '
                            '${totals.itemLines.length == 1 ? 'item' : 'items'}',
                            style:
                                TextStyle(color: tokens.onMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      key: ValueKey<String>('total-$name'),
                      totals.total.toStringAsFixed(2),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        Icons.chevron_right,
                        color: tokens.onMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (expanded)
                Container(
                  decoration: BoxDecoration(
                    color: tokens.surfaceLow,
                    border: Border(
                      top: BorderSide(color: tokens.outlineSoft),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: Column(
                    children: <Widget>[
                      for (final line in totals.itemLines)
                        _detailRow(line.label, line.amount, tokens),
                      if (totals.serviceShare > 0)
                        _detailRow(
                          'Share of service',
                          totals.serviceShare,
                          tokens,
                          isShare: true,
                          shareKey: ValueKey<String>('service-share-$name'),
                        ),
                      if (totals.taxShare > 0)
                        _detailRow(
                          'Share of tax',
                          totals.taxShare,
                          tokens,
                          isShare: true,
                          shareKey: ValueKey<String>('tax-share-$name'),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
    String label,
    double amount,
    BillSplitTokens tokens, {
    bool isShare = false,
    Key? shareKey,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isShare ? tokens.onMuted : tokens.onSurface,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            amount.toStringAsFixed(2),
            key: shareKey,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: tokens.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonAvatar extends StatelessWidget {
  final String name;
  final Color color;
  const _PersonAvatar({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 17,
        ),
      ),
    );
  }
}

// --- Math ---------------------------------------------------------------

/// One line item in a person's breakdown.
class _Line {
  final String label;
  final double amount;
  const _Line(this.label, this.amount);
}

class _PersonTotals {
  final List<_Line> itemLines;
  final double itemsSubtotal;
  final double taxShare;
  final double serviceShare;
  final double total;

  const _PersonTotals({
    required this.itemLines,
    required this.itemsSubtotal,
    required this.taxShare,
    required this.serviceShare,
    required this.total,
  });
}

class _TotalsResult {
  final Map<String, _PersonTotals> perPerson;
  final double itemsTotal;
  final double taxAdded;
  final double serviceAdded;
  final double billTotal;
  final double residual;

  const _TotalsResult({
    required this.perPerson,
    required this.itemsTotal,
    required this.taxAdded,
    required this.serviceAdded,
    required this.billTotal,
    required this.residual,
  });
}

double _roundCurrency(double v) => (v * 100).round() / 100;

_TotalsResult _computeTotals(BillState s) {
  final Map<String, double> itemsShare = <String, double>{
    for (final name in s.people) name: 0.0,
  };
  final Map<String, List<_Line>> perPersonLines = <String, List<_Line>>{
    for (final name in s.people) name: <_Line>[],
  };

  double itemsTotal = 0;
  for (final BillItem item in s.items) {
    itemsTotal += item.price;
    final assignees = s.assignments[item.id];
    if (assignees == null || assignees.isEmpty) continue;
    final totalWeight =
        assignees.values.fold<double>(0, (acc, w) => acc + w);
    if (totalWeight <= 0) continue;
    for (final entry in assignees.entries) {
      final share = item.price * (entry.value / totalWeight);
      itemsShare[entry.key] = (itemsShare[entry.key] ?? 0) + share;
      perPersonLines[entry.key]?.add(_Line(item.name, share));
    }
  }

  final double tax = s.tax ?? 0;
  final double service = s.service ?? 0;
  final bool addTax = !s.taxIncluded && tax > 0 && itemsTotal > 0;
  final bool addService = !s.serviceIncluded && service > 0 && itemsTotal > 0;

  final Map<String, _PersonTotals> result = <String, _PersonTotals>{};
  double sumOfRoundedTotals = 0;

  for (final name in s.people) {
    final subtotal = itemsShare[name] ?? 0;
    final taxShare = addTax ? subtotal / itemsTotal * tax : 0.0;
    final serviceShare = addService ? subtotal / itemsTotal * service : 0.0;
    final total = _roundCurrency(subtotal + taxShare + serviceShare);
    sumOfRoundedTotals += total;
    result[name] = _PersonTotals(
      itemLines: perPersonLines[name] ?? const <_Line>[],
      itemsSubtotal: subtotal,
      taxShare: _roundCurrency(taxShare),
      serviceShare: _roundCurrency(serviceShare),
      total: total,
    );
  }

  final double billTotal =
      itemsTotal + (addTax ? tax : 0) + (addService ? service : 0);
  final double residual = _roundCurrency(billTotal - sumOfRoundedTotals);

  return _TotalsResult(
    perPerson: result,
    itemsTotal: itemsTotal,
    taxAdded: addTax ? tax : 0,
    serviceAdded: addService ? service : 0,
    billTotal: billTotal,
    residual: residual,
  );
}
