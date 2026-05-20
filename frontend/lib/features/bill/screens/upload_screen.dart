import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/extract_repository.dart';
import '../model/item.dart';

typedef ImagePickerFn = Future<Uint8List?> Function(ImageSource source);

Future<Uint8List?> defaultPickImage(ImageSource source) async {
  final picker = ImagePicker();
  final file = await picker.pickImage(source: source, maxWidth: 4000);
  if (file == null) return null;
  return await file.readAsBytes();
}

enum _Mode { picker, busy, manualEntry }

class UploadScreen extends StatefulWidget {
  const UploadScreen({
    super.key,
    required this.repository,
    required this.onSuccess,
    required this.onFailure,
    this.pickImage,
  });

  final ExtractRepository repository;
  final ImagePickerFn? pickImage;
  final ValueChanged<ExtractResult> onSuccess;
  final ValueChanged<Object> onFailure;

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  _Mode _mode = _Mode.picker;
  String? _fallbackReason;

  ImagePickerFn get _pick => widget.pickImage ?? defaultPickImage;

  Future<void> _handle(ImageSource source) async {
    if (_mode == _Mode.busy) return;
    setState(() => _mode = _Mode.busy);
    try {
      final bytes = await _pick(source);
      if (bytes == null) {
        if (mounted) setState(() => _mode = _Mode.picker);
        return;
      }
      final result = await widget.repository.extract(bytes);
      if (!mounted) return;
      // FR-007 zero-items branch: route to manual entry.
      if (result.items.isEmpty) {
        setState(() {
          _mode = _Mode.manualEntry;
          _fallbackReason = AppLocalizations.of(context)!.extractionEmpty;
        });
        return;
      }
      widget.onSuccess(result);
    } catch (err) {
      if (!mounted) return;
      // FR-007 failure branch: swap inline to manual entry, do NOT bubble.
      setState(() {
        _mode = _Mode.manualEntry;
        _fallbackReason = describeError(context, err);
      });
    } finally {
      if (mounted && _mode == _Mode.busy) {
        setState(() => _mode = _Mode.picker);
      }
    }
  }

  void _completeManual(ExtractResult typed) {
    widget.onSuccess(typed);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.uploadScreenTitle)),
      body: switch (_mode) {
        _Mode.manualEntry => _ManualEntrySurface(
            key: const Key('manual-entry-surface'),
            reason: _fallbackReason ?? l.extractionFailed,
            onDone: _completeManual,
          ),
        _Mode.busy => const Center(child: CircularProgressIndicator()),
        _Mode.picker => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  key: const Key('upload-camera'),
                  onPressed: () => _handle(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(l.uploadFromCamera),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  key: const Key('upload-gallery'),
                  onPressed: () => _handle(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(l.uploadFromGallery),
                ),
              ],
            ),
          ),
      },
    );
  }
}

class _ManualEntrySurface extends StatefulWidget {
  const _ManualEntrySurface({super.key, required this.reason, required this.onDone});
  final String reason;
  final ValueChanged<ExtractResult> onDone;

  @override
  State<_ManualEntrySurface> createState() => _ManualEntrySurfaceState();
}

class _ManualEntryRow {
  _ManualEntryRow()
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

class _ManualEntrySurfaceState extends State<_ManualEntrySurface> {
  final List<_ManualEntryRow> _rows = [_ManualEntryRow()];

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() => _rows.add(_ManualEntryRow()));
  }

  void _removeAt(int i) {
    setState(() {
      _rows.removeAt(i).dispose();
      if (_rows.isEmpty) _rows.add(_ManualEntryRow());
    });
  }

  void _submit() {
    final items = <Item>[];
    for (final row in _rows) {
      final name = row.name.text.trim();
      final qty = int.tryParse(row.qty.text.trim()) ?? 1;
      final price = num.tryParse(row.price.text.trim());
      if (name.isEmpty || price == null) continue;
      items.add(Item.create(
        name: name,
        quantity: qty < 1 ? 1 : qty,
        unitPrice: price < 0 ? 0 : price,
        source: ItemSource.manual,
      ));
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item with a name and price.')),
      );
      return;
    }
    widget.onDone(ExtractResult(items: items, taxAmount: null, serviceAmount: null));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.reason,
              style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: _rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = _rows[i];
                return Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        key: Key('manual-item-name-$i'),
                        controller: r.name,
                        decoration: InputDecoration(labelText: l.itemNameLabel),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 56,
                      child: TextField(
                        key: Key('manual-item-qty-$i'),
                        controller: r.qty,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: l.itemQuantityLabel),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        key: Key('manual-item-price-$i'),
                        controller: r.price,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: l.itemPriceLabel),
                      ),
                    ),
                    IconButton(
                      key: Key('manual-item-remove-$i'),
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeAt(i),
                    ),
                  ],
                );
              },
            ),
          ),
          TextButton.icon(
            key: const Key('manual-add-item-button'),
            onPressed: _addRow,
            icon: const Icon(Icons.add),
            label: Text(l.addItemButton),
          ),
          ElevatedButton(
            key: const Key('manual-done-button'),
            onPressed: _submit,
            child: Text(l.nextButton),
          ),
        ],
      ),
    );
  }
}
