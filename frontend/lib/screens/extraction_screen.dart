import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:bill_split/services/extraction_client.dart';
import 'package:bill_split/state/bill_item.dart';
import 'package:bill_split/state/bill_state.dart';
import 'package:bill_split/theme.dart';
import 'package:bill_split/widgets/back_chevron.dart';
import 'package:bill_split/widgets/bottom_action_bar.dart';
import 'package:bill_split/widgets/flow_stepper.dart';

/// 001-bill-split-flow: extract receipt items via the backend (which proxies
/// to Gemini), let the user review/edit the result, then commit to bill state.
class ExtractionScreen extends StatefulWidget {
  final BillState billState;
  final ExtractionClient extractor;
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

  // `_taxEnabled` mirrors the Tax checkbox state — i.e. whether the receipt
  // has a tax line at all. `_taxOnTop` is the segmented control under it:
  // true = "Added on top", false = "Included in items". Stored separately
  // because the checkbox can flip on/off while the segmented choice persists.
  bool _taxEnabled = false;
  bool _taxOnTop = true;
  final TextEditingController _taxController =
      TextEditingController(text: '0');

  bool _serviceEnabled = false;
  bool _serviceOnTop = true;
  final TextEditingController _serviceController =
      TextEditingController(text: '0');

  @override
  void didUpdateWidget(covariant ExtractionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.billState, widget.billState)) {
      setState(() {
        for (final item in _items) {
          item.dispose();
        }
        _items.clear();
        _phase = _Phase.pre;
        _error = null;
        _taxEnabled = false;
        _taxOnTop = true;
        _serviceEnabled = false;
        _serviceOnTop = true;
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

      _taxEnabled = tax != null;
      if (tax != null) _taxController.text = tax.toString();

      _serviceEnabled = service != null;
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
    const uuid = Uuid();
    final committed = _items
        .where((_EditableItem i) => i.name.text.trim().isNotEmpty)
        .map((_EditableItem i) => BillItem(
              id: uuid.v4(),
              name: i.name.text.trim(),
              price: double.tryParse(i.price.text) ?? 0,
            ))
        .toList(growable: false);

    widget.billState.items = committed;
    widget.billState.tax = _taxEnabled
        ? (double.tryParse(_taxController.text) ?? 0)
        : null;
    widget.billState.taxIncluded = !_taxOnTop;
    widget.billState.service = _serviceEnabled
        ? (double.tryParse(_serviceController.text) ?? 0)
        : null;
    widget.billState.serviceIncluded = !_serviceOnTop;
    widget.billState.clearAssignments();
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const BackChevronBar(),
            const FlowStepper(step: 2),
            Expanded(child: _buildPhase(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildPhase(BuildContext context) {
    switch (_phase) {
      case _Phase.pre:
        return _buildPre(context);
      case _Phase.loading:
        return _buildLoading(context);
      case _Phase.error:
        return _buildError(context);
      case _Phase.editable:
        return _buildEditable(context);
    }
  }

  Widget _buildPre(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;
    final bytes = widget.billState.imageBytes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Ready to scan',
                style: theme.textTheme.displaySmall,
              ),
              const SizedBox(height: 6),
              Text(
                "We'll send the photo to the backend to pull out items and prices.",
                style: TextStyle(color: tokens.onMuted, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (bytes != null)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radius),
                child: Container(
                  color: const Color(0xFF1A1815),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(12),
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    errorBuilder: (BuildContext context, Object error,
                            StackTrace? stack) =>
                        const Icon(Icons.broken_image,
                            size: 64, color: Colors.white),
                  ),
                ),
              ),
            ),
          )
        else
          const Spacer(),
        BottomActionBar(
          child: ElevatedButton(
            onPressed: _runExtraction,
            child: const Text('Extract items'),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: tokens.surface,
                border: Border.all(color: tokens.outlineSoft),
                borderRadius: BorderRadius.circular(22),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(Icons.receipt_long, color: tokens.primary, size: 36),
            ),
            const SizedBox(height: 18),
            Text(
              'Reading your receipt…',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Pulling out item names and prices. This usually takes a few seconds.',
              style: TextStyle(color: tokens.onMuted, fontSize: 14, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;
    final isUnauthorized = _error?.kind == ExtractionFailure.unauthorized;
    final kind = _error?.kind.name ?? 'unknown';
    final headline = isUnauthorized
        ? 'Authentication required. Please reopen the app to sign in again, then retry.'
        : "We couldn't read the photo.";
    final sub = isUnauthorized
        ? (_error?.message ?? '')
        : 'Reason: $kind. Lighting, glare, or handwriting can throw it off. Retake the shot or type items in by hand.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.error_outline, size: 52, color: tokens.danger),
                const SizedBox(height: 14),
                Text(
                  headline,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                if (sub.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    sub,
                    style:
                        TextStyle(color: tokens.onMuted, fontSize: 14, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ElevatedButton(
                onPressed: _runExtraction,
                child: const Text('Retry'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _enterManualFallback,
                child: const Text('Enter items manually'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditable(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;
    final subtotal = _items.fold<double>(0, (acc, i) {
      return acc + (double.tryParse(i.price.text) ?? 0);
    });
    return Column(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      const TextSpan(text: 'Items '),
                      TextSpan(
                        text: 'found',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: tokens.primary,
                        ),
                      ),
                    ],
                  ),
                  style: theme.textTheme.displaySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap any row to edit. Long-press a price to fix it.',
                  style: TextStyle(color: tokens.onMuted, fontSize: 13.5),
                ),
                const SizedBox(height: 16),
                _itemsCard(tokens),
                const SizedBox(height: 18),
                _OverlineText(text: 'Receipt charges', tokens: tokens),
                const SizedBox(height: 8),
                _chargeRow(
                  label: 'Tax',
                  checkboxKey: const ValueKey<String>('tax-checkbox'),
                  amountKey: const ValueKey<String>('tax-amount-field'),
                  segmentKey: const ValueKey<String>('tax-segment'),
                  enabled: _taxEnabled,
                  onTop: _taxOnTop,
                  controller: _taxController,
                  onChangedEnabled: (bool? v) => setState(() {
                    _taxEnabled = v ?? false;
                    if (_taxEnabled) _taxController.text = '0';
                  }),
                  onChangedOnTop: (bool v) =>
                      setState(() => _taxOnTop = v),
                  tokens: tokens,
                ),
                const SizedBox(height: 8),
                _chargeRow(
                  label: 'Service',
                  checkboxKey: const ValueKey<String>('service-checkbox'),
                  amountKey: const ValueKey<String>('service-amount-field'),
                  segmentKey: const ValueKey<String>('service-segment'),
                  enabled: _serviceEnabled,
                  onTop: _serviceOnTop,
                  controller: _serviceController,
                  onChangedEnabled: (bool? v) => setState(() {
                    _serviceEnabled = v ?? false;
                    if (_serviceEnabled) _serviceController.text = '0';
                  }),
                  onChangedOnTop: (bool v) =>
                      setState(() => _serviceOnTop = v),
                  tokens: tokens,
                ),
                const SizedBox(height: 18),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: tokens.surfaceLow,
                    border: Border.all(color: tokens.outlineSoft),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        '${_items.length} items · subtotal',
                        style:
                            TextStyle(color: tokens.onMuted, fontSize: 13.5),
                      ),
                      Text(
                        subtotal.toStringAsFixed(2),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: tokens.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        BottomActionBar(
          child: ElevatedButton(
            onPressed: _canContinue ? _onContinue : null,
            child: const Text('Continue'),
          ),
        ),
      ],
    );
  }

  Widget _itemsCard(BillSplitTokens tokens) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.outlineSoft),
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < _items.length; i++)
            _buildItemRow(i, last: i == _items.length - 1, tokens: tokens),
          InkWell(
            onTap: _addItem,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: tokens.outlineSoft),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.add, size: 18, color: tokens.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Add item',
                    style: TextStyle(
                      color: tokens.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(int index, {required bool last, required BillSplitTokens tokens}) {
    final item = _items[index];
    return Container(
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: tokens.outlineSoft)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: TextField(
              controller: item.name,
              decoration: const InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'Item name',
              ),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            child: TextField(
              controller: item.price,
              decoration: const InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: '0.00',
              ),
              textAlign: TextAlign.right,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: tokens.onSurface,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete',
            color: tokens.onDim,
            iconSize: 20,
            onPressed: () => _removeItem(index),
          ),
        ],
      ),
    );
  }

  Widget _chargeRow({
    required String label,
    required Key checkboxKey,
    required Key amountKey,
    required Key segmentKey,
    required bool enabled,
    required bool onTop,
    required TextEditingController controller,
    required ValueChanged<bool?> onChangedEnabled,
    required ValueChanged<bool> onChangedOnTop,
    required BillSplitTokens tokens,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.outlineSoft),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: EdgeInsets.fromLTRB(8, 8, 12, enabled ? 12 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Checkbox(
                key: checkboxKey,
                value: enabled,
                onChanged: onChangedEnabled,
              ),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
              ),
              if (enabled)
                SizedBox(
                  width: 100,
                  child: TextField(
                    key: amountKey,
                    controller: controller,
                    textAlign: TextAlign.right,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: tokens.outlineSoft),
                      ),
                      hintText: '0.00',
                    ),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: tokens.onSurface,
                    ),
                  ),
                ),
            ],
          ),
          if (enabled) ...<Widget>[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'How is it charged?',
                    style:
                        TextStyle(color: tokens.onMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  _SegmentedTwo(
                    key: segmentKey,
                    leftLabel: 'Included in items',
                    rightLabel: 'Added on top',
                    rightSelected: onTop,
                    onChanged: onChangedOnTop,
                    tokens: tokens,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pill-shaped 2-option segmented control used under each enabled charge.
/// `rightSelected = true` means the right option is active (e.g.
/// "Added on top"); `false` means the left option is active ("Included in
/// items"). Emits the new `rightSelected` value via [onChanged].
class _SegmentedTwo extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;
  final bool rightSelected;
  final ValueChanged<bool> onChanged;
  final BillSplitTokens tokens;

  const _SegmentedTwo({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.rightSelected,
    required this.onChanged,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: tokens.surfaceLow,
        border: Border.all(color: tokens.outlineSoft),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _SegBtn(
              label: leftLabel,
              selected: !rightSelected,
              onTap: () => onChanged(false),
              tokens: tokens,
            ),
          ),
          Expanded(
            child: _SegBtn(
              label: rightLabel,
              selected: rightSelected,
              onTap: () => onChanged(true),
              tokens: tokens,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final BillSplitTokens tokens;

  const _SegBtn({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(99),
      elevation: selected ? 1 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? tokens.onSurface : tokens.onMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlineText extends StatelessWidget {
  final String text;
  final BillSplitTokens tokens;
  const _OverlineText({required this.text, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
        color: tokens.onDim,
      ),
    );
  }
}
