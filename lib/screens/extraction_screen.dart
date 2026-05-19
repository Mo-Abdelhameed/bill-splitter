import 'package:flutter/material.dart';

import 'package:bill_split/services/gemini_extractor.dart';
import 'package:bill_split/state/bill_item.dart';
import 'package:bill_split/state/bill_state.dart';

/// STORY-002: extract receipt items via Gemini, let the user review/edit
/// the result, then commit to bill state.
class ExtractionScreen extends StatefulWidget {
  final BillState billState;
  final GeminiExtractor extractor;
  final VoidCallback onContinue;

  const ExtractionScreen({
    super.key,
    required this.billState,
    required this.extractor,
    required this.onContinue,
  });

  @override
  State<ExtractionScreen> createState() => _ExtractionScreenState();
}

enum _Phase { pre, loading, editable, error }

class _EditableItem {
  final TextEditingController name;
  final TextEditingController price;

  _EditableItem({String initialName = '', String initialPrice = '0'})
      : name = TextEditingController(text: initialName),
        price = TextEditingController(text: initialPrice);

  void dispose() {
    name.dispose();
    price.dispose();
  }
}

class _ExtractionScreenState extends State<ExtractionScreen> {
  _Phase _phase = _Phase.pre;
  ExtractionException? _error;

  final List<_EditableItem> _items = <_EditableItem>[];

  bool _taxIncluded = false;
  final TextEditingController _taxController =
      TextEditingController(text: '0');

  bool _serviceIncluded = false;
  final TextEditingController _serviceController =
      TextEditingController(text: '0');

  @override
  void didUpdateWidget(covariant ExtractionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the parent swaps in a different BillState instance, treat that as a
    // fresh extraction context: reset the screen back to its pre-extraction
    // state and forget any cached UI.
    if (!identical(oldWidget.billState, widget.billState)) {
      setState(() {
        for (final item in _items) {
          item.dispose();
        }
        _items.clear();
        _phase = _Phase.pre;
        _error = null;
        _taxIncluded = false;
        _serviceIncluded = false;
        _taxController.text = '0';
        _serviceController.text = '0';
      });
    }
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    _taxController.dispose();
    _serviceController.dispose();
    super.dispose();
  }

  Future<void> _runExtraction() async {
    final imageBytes = widget.billState.imageBytes;
    if (imageBytes == null) return;

    setState(() {
      _phase = _Phase.loading;
      _error = null;
    });

    try {
      final result = await widget.extractor.extract(imageBytes);
      _enterEditable(
        result.items,
        tax: result.tax,
        service: result.service,
      );
    } catch (e) {
      setState(() {
        _phase = _Phase.error;
        _error = e is ExtractionException
            ? e
            : ExtractionException(ExtractionFailure.network, e.toString());
      });
    }
  }

  void _enterEditable(
    List<BillItem> items, {
    double? tax,
    double? service,
  }) {
    setState(() {
      for (final item in _items) {
        item.dispose();
      }
      _items
        ..clear()
        ..addAll(items.map((BillItem i) => _EditableItem(
              initialName: i.name,
              initialPrice: i.price.toString(),
            )));

      _taxIncluded = tax != null;
      if (tax != null) _taxController.text = tax.toString();

      _serviceIncluded = service != null;
      if (service != null) _serviceController.text = service.toString();

      _phase = _Phase.editable;
      _error = null;
    });
  }

  void _enterManualFallback() {
    _enterEditable(const <BillItem>[]);
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index).dispose();
    });
  }

  void _addItem() {
    setState(() {
      _items.add(_EditableItem());
    });
  }

  bool get _canContinue =>
      _items.any((_EditableItem i) => i.name.text.trim().isNotEmpty);

  void _onContinue() {
    final committed = _items
        .where((_EditableItem i) => i.name.text.trim().isNotEmpty)
        .map((_EditableItem i) => BillItem(
              name: i.name.text.trim(),
              price: double.tryParse(i.price.text) ?? 0,
            ))
        .toList(growable: false);

    widget.billState.items = committed;
    widget.billState.tax = _taxIncluded
        ? (double.tryParse(_taxController.text) ?? 0)
        : null;
    widget.billState.service = _serviceIncluded
        ? (double.tryParse(_serviceController.text) ?? 0)
        : null;
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt items')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (widget.billState.imageBytes != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SizedBox(
                    height: 200,
                    child: Image.memory(
                      widget.billState.imageBytes!,
                      fit: BoxFit.contain,
                      errorBuilder: (BuildContext context, Object error,
                              StackTrace? stack) =>
                          const Icon(Icons.broken_image, size: 64),
                    ),
                  ),
                ),
              Expanded(child: _buildPhase()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.pre:
        return Center(
          child: ElevatedButton(
            onPressed: _runExtraction,
            child: const Text('Extract items'),
          ),
        );
      case _Phase.loading:
        return const Center(child: CircularProgressIndicator());
      case _Phase.error:
        return _buildError();
      case _Phase.editable:
        return _buildEditable();
    }
  }

  Widget _buildError() {
    final kind = _error?.kind.name ?? 'unknown';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text('Extraction failed: $kind'),
          if ((_error?.message ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!.message, style: const TextStyle(fontSize: 12)),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _runExtraction,
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: _enterManualFallback,
            child: const Text('Enter items manually'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < _items.length; i++) _buildItemRow(i),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Add item'),
                  ),
                ),
                const Divider(),
                _checkboxRow(
                  checkboxKey: const ValueKey<String>('tax-checkbox'),
                  amountKey: const ValueKey<String>('tax-amount-field'),
                  label: 'Tax included',
                  included: _taxIncluded,
                  controller: _taxController,
                  onChanged: (bool? v) => setState(() {
                    _taxIncluded = v ?? false;
                    if (_taxIncluded) _taxController.text = '0';
                  }),
                ),
                _checkboxRow(
                  checkboxKey: const ValueKey<String>('service-checkbox'),
                  amountKey: const ValueKey<String>('service-amount-field'),
                  label: 'Service included',
                  included: _serviceIncluded,
                  controller: _serviceController,
                  onChanged: (bool? v) => setState(() {
                    _serviceIncluded = v ?? false;
                    if (_serviceIncluded) _serviceController.text = '0';
                  }),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _canContinue ? _onContinue : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildItemRow(int index) {
    final item = _items[index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: TextField(
              controller: item.name,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: item.price,
              decoration: const InputDecoration(
                labelText: 'Price',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete',
            onPressed: () => _removeItem(index),
          ),
        ],
      ),
    );
  }

  Widget _checkboxRow({
    required Key checkboxKey,
    required Key amountKey,
    required String label,
    required bool included,
    required TextEditingController controller,
    required ValueChanged<bool?> onChanged,
  }) {
    return Row(
      children: <Widget>[
        Checkbox(
          key: checkboxKey,
          value: included,
          onChanged: onChanged,
        ),
        Text(label),
        const SizedBox(width: 12),
        if (included)
          Expanded(
            child: TextField(
              key: amountKey,
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
      ],
    );
  }
}
