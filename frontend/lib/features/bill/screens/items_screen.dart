import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/ui/bill_stepper.dart';
import '../../../core/ui/bottom_action_bar.dart';
import '../../../core/ui/display_title.dart';
import '../../../core/ui/pill_button.dart';
import '../../../l10n/app_localizations.dart';
import '../model/item.dart';

class ItemsScreenResult {
  ItemsScreenResult({
    required this.items,
    required this.taxAmount,
    required this.serviceAmount,
  });
  final List<Item> items;
  final num? taxAmount;
  final num? serviceAmount;
}

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({
    super.key,
    required this.initialItems,
    required this.initialTaxAmount,
    required this.initialServiceAmount,
    required this.onProceed,
  });

  final List<Item> initialItems;
  final num? initialTaxAmount;
  final num? initialServiceAmount;
  final ValueChanged<ItemsScreenResult> onProceed;

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

const num _kDefaultServicePct = 0.12;
const num _kDefaultTaxPct = 0.14;

class _ExistingRow {
  _ExistingRow(this.item)
      : name = TextEditingController(text: item.name),
        qty = TextEditingController(text: item.quantity.toString()),
        price = TextEditingController(text: _formatPrice(item.unitPrice));
  final Item item;
  final TextEditingController name;
  final TextEditingController qty;
  final TextEditingController price;
  void dispose() {
    name.dispose();
    qty.dispose();
    price.dispose();
  }
}

class _NewRow {
  _NewRow()
      : name = TextEditingController(),
        qty = TextEditingController(text: '1'),
        price = TextEditingController();
  final TextEditingController name;
  final TextEditingController qty;
  final TextEditingController price;
  void dispose() {
    name.dispose();
    qty.dispose();
    price.dispose();
  }
}

String _formatPrice(num value) {
  if (value == value.truncateToDouble()) return value.toInt().toString();
  return value.toString();
}

class _ItemsScreenState extends State<ItemsScreen> {
  late final List<_ExistingRow> _existing;
  final List<_NewRow> _added = [];
  late final TextEditingController _taxController;
  late final TextEditingController _serviceController;

  @override
  void initState() {
    super.initState();
    _existing = widget.initialItems.map(_ExistingRow.new).toList();
    final initialSubtotal = widget.initialItems
        .fold<num>(0, (s, i) => s + i.quantity * i.unitPrice);
    final tax = widget.initialTaxAmount ?? _round(initialSubtotal * _kDefaultTaxPct);
    final service =
        widget.initialServiceAmount ?? _round(initialSubtotal * _kDefaultServicePct);
    _taxController = TextEditingController(text: _formatPrice(tax));
    _serviceController = TextEditingController(text: _formatPrice(service));
  }

  num _round(num v) {
    if (v == v.truncateToDouble()) return v;
    return double.parse(v.toStringAsFixed(2));
  }

  @override
  void dispose() {
    for (final r in _existing) {
      r.dispose();
    }
    for (final r in _added) {
      r.dispose();
    }
    _taxController.dispose();
    _serviceController.dispose();
    super.dispose();
  }

  void _addRow() => setState(() => _added.add(_NewRow()));
  void _deleteExisting(int i) =>
      setState(() => _existing.removeAt(i).dispose());
  void _deleteNew(int i) => setState(() => _added.removeAt(i).dispose());

  void _submit() {
    final items = <Item>[];
    for (final row in _existing) {
      final name = row.name.text.trim().isEmpty
          ? row.item.name
          : row.name.text.trim();
      final qty = int.tryParse(row.qty.text.trim()) ?? row.item.quantity;
      final price = num.tryParse(row.price.text.trim()) ?? row.item.unitPrice;
      items.add(row.item.copyWith(
        name: name,
        quantity: qty < 1 ? 1 : qty,
        unitPrice: price < 0 ? 0 : price,
      ));
    }
    for (final row in _added) {
      final name = row.name.text.trim();
      final price = num.tryParse(row.price.text.trim());
      final qty = int.tryParse(row.qty.text.trim()) ?? 1;
      if (name.isEmpty || price == null) continue;
      items.add(Item.create(
        name: name,
        quantity: qty < 1 ? 1 : qty,
        unitPrice: price < 0 ? 0 : price,
        source: ItemSource.manual,
      ));
    }
    final tax = _parseAmount(_taxController.text);
    final service = _parseAmount(_serviceController.text);
    widget.onProceed(ItemsScreenResult(
      items: items,
      taxAmount: tax,
      serviceAmount: service,
    ));
  }

  num? _parseAmount(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return num.tryParse(t);
  }

  num get _itemsSubtotal {
    num total = 0;
    for (final row in _existing) {
      final qty = int.tryParse(row.qty.text) ?? row.item.quantity;
      final price = num.tryParse(row.price.text) ?? row.item.unitPrice;
      total += qty * price;
    }
    for (final row in _added) {
      final qty = int.tryParse(row.qty.text) ?? 1;
      final price = num.tryParse(row.price.text) ?? 0;
      total += qty * price;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(toolbarHeight: 36),
      body: Column(
        children: [
          const BillStepper(step: 2),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              children: [
                DisplayTitle.rich(
                  [
                    DisplayTitle.plain('Items '),
                    DisplayTitle.accent('found'),
                    DisplayTitle.plain('.'),
                  ],
                  size: 28,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap any field to edit. Add or remove rows as needed.',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppTokens.onMuted),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: AppTokens.surface,
                    borderRadius: BorderRadius.circular(AppTokens.radius),
                    border: Border.all(color: AppTokens.outlineSoft),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < _existing.length; i++)
                        _itemRow(
                          row: _existing[i],
                          keyPrefix: _existing[i].item.id,
                          isLast: i == _existing.length - 1 && _added.isEmpty,
                          onDelete: () => _deleteExisting(i),
                          l: l,
                        ),
                      for (var i = 0; i < _added.length; i++)
                        _newItemRow(
                          row: _added[i],
                          displayIndex: _existing.length + i,
                          isLast: i == _added.length - 1,
                          onDelete: () => _deleteNew(i),
                          l: l,
                        ),
                      InkWell(
                        key: const Key('items-add-button'),
                        onTap: _addRow,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppTokens.radius)),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: AppTokens.outlineSoft)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.add, color: AppTokens.primary, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                l.addItemButton,
                                style: const TextStyle(
                                  color: AppTokens.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _Overline('Receipt charges'),
                const SizedBox(height: 8),
                _chargeField(
                  keyName: 'items-service-field',
                  label: l.serviceLabel,
                  pct: '12%',
                  controller: _serviceController,
                ),
                const SizedBox(height: 8),
                _chargeField(
                  keyName: 'items-tax-field',
                  label: l.taxLabel,
                  pct: '14%',
                  controller: _taxController,
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTokens.surfaceLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTokens.outlineSoft),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_existing.length + _added.length} items · subtotal',
                          style: const TextStyle(fontSize: 13.5, color: AppTokens.onMuted),
                        ),
                      ),
                      Text(
                        '${l.currencyEgp} ${_formatPrice(_itemsSubtotal)}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          BottomActionBar(
            child: PillButton(
              key: const Key('items-next-button'),
              label: l.nextButton,
              icon: Icons.arrow_forward,
              iconAtEnd: true,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemRow({
    required _ExistingRow row,
    required String keyPrefix,
    required bool isLast,
    required VoidCallback onDelete,
    required AppLocalizations l,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppTokens.outlineSoft)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              key: Key('item-name-$keyPrefix'),
              controller: row.name,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 48,
            child: TextField(
              key: Key('item-qty-$keyPrefix'),
              controller: row.qty,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 84,
            child: TextField(
              key: Key('item-price-$keyPrefix'),
              controller: row.price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.end,
              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            key: Key('item-delete-$keyPrefix'),
            icon: const Icon(Icons.delete_outline, size: 18),
            color: AppTokens.onDim,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _newItemRow({
    required _NewRow row,
    required int displayIndex,
    required bool isLast,
    required VoidCallback onDelete,
    required AppLocalizations l,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppTokens.outlineSoft)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              key: Key('item-name-new-$displayIndex'),
              controller: row.name,
              decoration: InputDecoration(hintText: l.itemNameLabel),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 48,
            child: TextField(
              key: Key('item-qty-new-$displayIndex'),
              controller: row.qty,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 84,
            child: TextField(
              key: Key('item-price-new-$displayIndex'),
              controller: row.price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.end,
              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            key: Key('item-delete-new-$displayIndex'),
            icon: const Icon(Icons.delete_outline, size: 18),
            color: AppTokens.onDim,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _chargeField({
    required String keyName,
    required String label,
    required String pct,
    required TextEditingController controller,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTokens.outlineSoft),
      ),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: AppTokens.onSurface, fontSize: 14.5, fontWeight: FontWeight.w600),
                children: [
                  TextSpan(text: '$label '),
                  TextSpan(
                    text: pct,
                    style: const TextStyle(color: AppTokens.onMuted, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: TextField(
              key: Key(keyName),
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.end,
              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Overline extends StatelessWidget {
  const _Overline(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
        color: AppTokens.onDim,
      ),
    );
  }
}
