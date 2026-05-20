import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme.dart';
import '../../../core/ui/bill_stepper.dart';
import '../../../core/ui/bottom_action_bar.dart';
import '../../../core/ui/display_title.dart';
import '../../../core/ui/inline_hint.dart';
import '../../../core/ui/pill_button.dart';
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
      setState(() {
        _mode = _Mode.manualEntry;
        _fallbackReason = AppLocalizations.of(context)!.extractionFailed;
      });
      widget.onFailure(err);
    } finally {
      if (mounted && _mode == _Mode.busy) {
        setState(() => _mode = _Mode.picker);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(toolbarHeight: 36),
      body: Column(
        children: [
          const BillStepper(step: 1),
          Expanded(
            child: switch (_mode) {
              _Mode.manualEntry => _ManualEntrySurface(
                  key: const Key('manual-entry-surface'),
                  reason: _fallbackReason ?? l.extractionFailed,
                  onDone: widget.onSuccess,
                ),
              _Mode.busy => _BusyOverlay(),
              _Mode.picker => _PickerSurface(
                  onCamera: () => _handle(ImageSource.camera),
                  onGallery: () => _handle(ImageSource.gallery),
                  onManual: () =>
                      setState(() => _mode = _Mode.manualEntry),
                ),
            },
          ),
        ],
      ),
    );
  }
}

class _PickerSurface extends StatelessWidget {
  const _PickerSurface({
    required this.onCamera,
    required this.onGallery,
    required this.onManual,
  });
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        DisplayTitle.rich(
          [
            DisplayTitle.plain('Snap the '),
            DisplayTitle.accent('receipt'),
            DisplayTitle.plain('.'),
          ],
          size: 34,
        ),
        const SizedBox(height: 8),
        Text(
          'Place the receipt on a flat surface in good light. We’ll pull out the items.',
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: AppTokens.onMuted, height: 1.4),
        ),
        const SizedBox(height: 28),
        Center(child: _ReceiptIllustration()),
        const SizedBox(height: 28),
        _CtaCard(
          keyName: 'upload-camera',
          icon: Icons.photo_camera_outlined,
          title: l.uploadFromCamera,
          desc: 'Camera',
          primary: true,
          onTap: onCamera,
        ),
        const SizedBox(height: 12),
        _CtaCard(
          keyName: 'upload-gallery',
          icon: Icons.photo_library_outlined,
          title: l.uploadFromGallery,
          desc: 'Choose an existing photo',
          onTap: onGallery,
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: onManual,
            child: Text(
              l.uploadOrEnterManually,
              style: const TextStyle(
                color: AppTokens.primary,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BusyOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppTokens.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTokens.outlineSoft),
              boxShadow: const [
                BoxShadow(color: Color(0x12000000), blurRadius: 18, offset: Offset(0, 6)),
              ],
            ),
            child: const Center(
              child: Icon(Icons.receipt_long, size: 32, color: AppTokens.primary),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Reading your receipt…',
            style: Theme.of(context).textTheme.displaySmall!.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 8),
          const SizedBox(
            width: 220,
            child: Text(
              'Pulling out item names and prices. This usually takes a few seconds.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTokens.onMuted, height: 1.4),
            ),
          ),
          const SizedBox(height: 18),
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ],
      ),
    );
  }
}

class _CtaCard extends StatelessWidget {
  const _CtaCard({
    required this.keyName,
    required this.icon,
    required this.title,
    required this.desc,
    required this.onTap,
    this.primary = false,
  });
  final String keyName;
  final IconData icon;
  final String title;
  final String desc;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final bg = primary ? AppTokens.primary : AppTokens.surface;
    final fg = primary ? Colors.white : AppTokens.onSurface;
    final tileBg = primary ? Colors.white.withValues(alpha: 0.15) : AppTokens.primaryContainer;
    final tileFg = primary ? Colors.white : AppTokens.onPrimaryContainer;
    return Material(
      key: Key(keyName),
      color: bg,
      borderRadius: BorderRadius.circular(AppTokens.radius),
      elevation: primary ? 2 : 0,
      shadowColor: primary ? AppTokens.primary.withValues(alpha: 0.4) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tileBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: tileFg),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5, color: fg),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 13,
                        color: fg.withValues(alpha: primary ? 0.85 : 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, color: fg.withValues(alpha: 0.7), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 220,
      child: CustomPaint(painter: _ReceiptPainter()),
    );
  }
}

class _ReceiptPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final body = Paint()..color = AppTokens.surface;
    final stroke = Paint()
      ..color = AppTokens.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.105);
    canvas.translate(-size.width / 2, -size.height / 2);
    final path = Path()
      ..moveTo(40, 20)
      ..lineTo(160, 20)
      ..lineTo(160, 195)
      ..lineTo(150, 188)
      ..lineTo(138, 195)
      ..lineTo(126, 188)
      ..lineTo(114, 195)
      ..lineTo(102, 188)
      ..lineTo(90, 195)
      ..lineTo(78, 188)
      ..lineTo(66, 195)
      ..lineTo(54, 188)
      ..lineTo(40, 195)
      ..close();
    canvas.drawPath(path, body);
    canvas.drawPath(path, stroke);
    final muted = Paint()..color = AppTokens.onDim;
    final accent = Paint()..color = AppTokens.primary;
    final dark = Paint()..color = AppTokens.onSurface;
    canvas.drawRRect(RRect.fromLTRBR(56, 38, 144, 42, const Radius.circular(2)), dark);
    for (var i = 0; i < 4; i++) {
      final y = 76 + i * 14.0;
      canvas.drawRRect(RRect.fromLTRBR(56, y, 124, y + 3, const Radius.circular(1)), muted);
      canvas.drawRRect(RRect.fromLTRBR(124, y, 146, y + 3, const Radius.circular(1)), muted);
    }
    canvas.drawRRect(RRect.fromLTRBR(56, 166, 92, 170, const Radius.circular(1.5)), dark);
    canvas.drawRRect(RRect.fromLTRBR(118, 166, 146, 170, const Radius.circular(1.5)), accent);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
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

  void _add() => setState(() => _rows.add(_ManualEntryRow()));

  void _removeAt(int i) {
    setState(() {
      _rows.removeAt(i).dispose();
      if (_rows.isEmpty) _rows.add(_ManualEntryRow());
    });
  }

  void _submit() {
    final items = <Item>[];
    for (final r in _rows) {
      final name = r.name.text.trim();
      final qty = int.tryParse(r.qty.text.trim()) ?? 1;
      final price = num.tryParse(r.price.text.trim());
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
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            children: [
              InlineHint(message: widget.reason, tone: HintTone.warn),
              const SizedBox(height: 16),
              DisplayTitle.rich(
                [
                  DisplayTitle.plain('Type them '),
                  DisplayTitle.accent('in'),
                  DisplayTitle.plain('.'),
                ],
                size: 28,
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
                    for (var i = 0; i < _rows.length; i++)
                      _manualRow(_rows[i], i, isLast: i == _rows.length - 1, l: l),
                    InkWell(
                      onTap: _add,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppTokens.radius)),
                      child: Container(
                        key: const Key('manual-add-item-button'),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: AppTokens.outlineSoft)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.add, color: AppTokens.primary, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Add item',
                              style: TextStyle(
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
            ],
          ),
        ),
        BottomActionBar(
          child: PillButton(
            key: const Key('manual-done-button'),
            label: l.nextButton,
            icon: Icons.arrow_forward,
            iconAtEnd: true,
            onPressed: _submit,
          ),
        ),
      ],
    );
  }

  Widget _manualRow(_ManualEntryRow r, int i, {required bool isLast, required AppLocalizations l}) {
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
              key: Key('manual-item-name-$i'),
              controller: r.name,
              decoration: InputDecoration(hintText: l.itemNameLabel),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 48,
            child: TextField(
              key: Key('manual-item-qty-$i'),
              controller: r.qty,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: l.itemQuantityLabel),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 84,
            child: TextField(
              key: Key('manual-item-price-$i'),
              controller: r.price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(hintText: l.itemPriceLabel),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: AppTokens.onDim,
            onPressed: () => _removeAt(i),
          ),
        ],
      ),
    );
  }
}
