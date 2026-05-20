import 'package:flutter/material.dart';

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

// FR-014: Egypt locale defaults when the extractor returned nothing.
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

    final tax = widget.initialTaxAmount ??
        _round(initialSubtotal * _kDefaultTaxPct);
    final service = widget.initialServiceAmount ??
        _round(initialSubtotal * _kDefaultServicePct);

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

  void _addRow() {
    setState(() => _added.add(_NewRow()));
  }

  void _deleteExisting(int i) {
    setState(() => _existing.removeAt(i).dispose());
  }

  void _deleteNew(int i) {
    setState(() => _added.removeAt(i).dispose());
  }

  void _submit() {
    final items = <Item>[];
    for (final row in _existing) {
      final name = row.name.text.trim().isEmpty ? row.item.name : row.name.text.trim();
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.itemsScreenTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                children: [
                  for (var i = 0; i < _existing.length; i++)
                    _existingRowTile(_existing[i], i),
                  for (var i = 0; i < _added.length; i++)
                    _newRowTile(_added[i], _existing.length + i, i),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      key: const Key('items-add-button'),
                      onPressed: _addRow,
                      icon: const Icon(Icons.add),
                      label: Text(l.addItemButton),
                    ),
                  ),
                  const Divider(height: 24),
                  _chargeField(
                    keyName: 'items-tax-field',
                    label: l.taxLabel,
                    controller: _taxController,
                  ),
                  const SizedBox(height: 8),
                  _chargeField(
                    keyName: 'items-service-field',
                    label: l.serviceLabel,
                    controller: _serviceController,
                  ),
                ],
              ),
            ),
            ElevatedButton(
              key: const Key('items-next-button'),
              onPressed: _submit,
              child: Text(l.nextButton),
            ),
          ],
        ),
      ),
    );
  }

  Widget _existingRowTile(_ExistingRow row, int i) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              key: Key('item-name-${row.item.id}'),
              controller: row.name,
              decoration: const InputDecoration(isDense: true),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 48,
            child: TextField(
              key: Key('item-qty-${row.item.id}'),
              controller: row.qty,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 84,
            child: TextField(
              key: Key('item-price-${row.item.id}'),
              controller: row.price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(isDense: true),
            ),
          ),
          IconButton(
            key: Key('item-delete-${row.item.id}'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteExisting(i),
          ),
        ],
      ),
    );
  }

  Widget _newRowTile(_NewRow row, int displayIndex, int addedIndex) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              key: Key('item-name-new-$displayIndex'),
              controller: row.name,
              decoration: const InputDecoration(isDense: true),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 48,
            child: TextField(
              key: Key('item-qty-new-$displayIndex'),
              controller: row.qty,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 84,
            child: TextField(
              key: Key('item-price-new-$displayIndex'),
              controller: row.price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(isDense: true),
            ),
          ),
          IconButton(
            key: Key('item-delete-new-$displayIndex'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteNew(addedIndex),
          ),
        ],
      ),
    );
  }

  Widget _chargeField({
    required String keyName,
    required String label,
    required TextEditingController controller,
  }) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        SizedBox(
          width: 100,
          child: TextField(
            key: Key(keyName),
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(isDense: true),
          ),
        ),
      ],
    );
  }
}
