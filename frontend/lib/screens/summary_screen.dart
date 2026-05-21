import 'package:flutter/material.dart';

import '../main.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final TextEditingController _taxCtrl = TextEditingController();
  final TextEditingController _svcCtrl = TextEditingController();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final session = SessionScope.of(context);
    _taxCtrl.text = _fmt(session.charges.tax);
    _svcCtrl.text = _fmt(session.charges.service);
    _initialized = true;
  }

  static String _fmt(double? v) => v == null ? '' : v.toStringAsFixed(2);

  @override
  void dispose() {
    _taxCtrl.dispose();
    _svcCtrl.dispose();
    super.dispose();
  }

  double? _parse(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    if (v == null || v < 0) return null;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final totals = session.computeTotals();
    final unassigned = session.unassigned;
    final hasUnassigned = unassigned.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Totals')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _taxCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Tax',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (s) => session.setTaxOverride(_parse(s)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _svcCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Service',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (s) => session.setServiceOverride(_parse(s)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasUnassigned)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Cannot finalize: ${unassigned.length} item(s) unassigned: '
                  '${unassigned.map((i) => i.name).join(", ")}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          ...totals.perDiner.map((t) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.diner.name,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      _row('Subtotal', t.subtotal),
                      _row('Tax share', t.taxShare),
                      _row('Service share', t.serviceShare),
                      const Divider(height: 16),
                      _row('Total', t.grandTotal, bold: true),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('Bill total', totals.billGrandTotal, bold: true),
                  if (totals.roundingResidualCents != 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Rounding residual: '
                        '\$${totals.roundingResidual.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: hasUnassigned
                ? null
                : () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Split finalized')),
                    ),
            child: const Text('Finalize'),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, double value, {bool bold = false}) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.bold)
        : const TextStyle();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('\$${value.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }
}
