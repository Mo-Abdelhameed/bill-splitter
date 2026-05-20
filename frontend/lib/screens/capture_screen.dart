import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:bill_split/services/image_acquirer.dart';
import 'package:bill_split/services/image_resizer.dart';
import 'package:bill_split/state/bill_state.dart';
import 'package:bill_split/theme.dart';
import 'package:bill_split/widgets/back_chevron.dart';
import 'package:bill_split/widgets/bottom_action_bar.dart';
import 'package:bill_split/widgets/flow_stepper.dart';

/// Image acquisition. Two CTAs (camera + gallery), preview state after
/// acquire, inline permission-denied errors, and a "no image selected"
/// toast on cancel.
class CaptureScreen extends StatefulWidget {
  final BillState billState;
  final ImageAcquirer acquirer;
  final ImageResizer resizer;
  final VoidCallback onContinue;

  const CaptureScreen({
    super.key,
    required this.billState,
    required this.acquirer,
    required this.resizer,
    required this.onContinue,
  });

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

enum _Phase { pre, preview }

class _CaptureScreenState extends State<CaptureScreen> {
  _Phase _phase = _Phase.pre;
  bool _cameraDenied = false;
  bool _galleryDenied = false;

  Future<void> _onTakePhoto() async {
    setState(() => _cameraDenied = false);
    try {
      final bytes = await widget.acquirer.takePhoto();
      await _handleAcquired(bytes);
    } on PermissionDeniedException catch (e) {
      if (!mounted) return;
      if (e.source == ImagePermissionSource.camera) {
        setState(() => _cameraDenied = true);
      } else {
        setState(() => _galleryDenied = true);
      }
    }
  }

  Future<void> _onPickFromGallery() async {
    setState(() => _galleryDenied = false);
    try {
      final bytes = await widget.acquirer.pickFromGallery();
      await _handleAcquired(bytes);
    } on PermissionDeniedException catch (e) {
      if (!mounted) return;
      if (e.source == ImagePermissionSource.gallery) {
        setState(() => _galleryDenied = true);
      } else {
        setState(() => _cameraDenied = true);
      }
    }
  }

  Future<void> _handleAcquired(Uint8List? bytes) async {
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No image selected')),
      );
      return;
    }
    final resized = await widget.resizer.resize(bytes, maxLongEdge: 1600);
    if (!mounted) return;
    setState(() {
      widget.billState.imageBytes = resized;
      _phase = _Phase.preview;
    });
  }

  void _onUseThisPhoto() {
    widget.onContinue();
  }

  void _onRetake() {
    setState(() {
      widget.billState.imageBytes = null;
      _phase = _Phase.pre;
      _cameraDenied = false;
      _galleryDenied = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const BackChevronBar(),
            const FlowStepper(step: 1),
            Expanded(
              child: switch (_phase) {
                _Phase.pre => _buildInitial(context),
                _Phase.preview => _buildPreview(context),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitial(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                const TextSpan(text: 'Snap the '),
                TextSpan(
                  text: 'receipt',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: tokens.primary,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
            style: theme.textTheme.displayMedium,
          ),
          const SizedBox(height: 8),
          Text(
            "Place the receipt on a flat surface in good light. We'll pull out the items.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tokens.onMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          _CTACard(
            icon: Icons.photo_camera,
            title: 'Take Photo',
            subtitle: 'Camera',
            primary: true,
            onTap: _onTakePhoto,
          ),
          if (_cameraDenied)
            _PermissionDeniedBlock(
              key: const ValueKey<String>('camera-permission-error'),
              tokens: tokens,
              message: 'Camera permission denied.',
              onOpenSettings: () => widget.acquirer.openAppSettings(),
            ),
          const SizedBox(height: 12),
          _CTACard(
            icon: Icons.photo_library_outlined,
            title: 'Pick from Gallery',
            subtitle: 'Choose an existing photo',
            primary: false,
            onTap: _onPickFromGallery,
          ),
          if (_galleryDenied)
            _PermissionDeniedBlock(
              key: const ValueKey<String>('gallery-permission-error'),
              tokens: tokens,
              message: 'Photo library permission denied.',
              onOpenSettings: () => widget.acquirer.openAppSettings(),
            ),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final tokens = Theme.of(context).tokens;
    final bytes = widget.billState.imageBytes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Looks good?',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  "We'll scan this and pull out the items.",
                  style: TextStyle(color: tokens.onMuted, fontSize: 14),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(tokens.radius),
                    child: Container(
                      color: const Color(0xFF1A1815),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(12),
                      child: bytes == null
                          ? const SizedBox.shrink()
                          : Image.memory(
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
              ],
            ),
          ),
        ),
        BottomActionBar(
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _onRetake,
                  child: const Text('Retake or repick'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _onUseThisPhoto,
                  child: const Text('Use this photo'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Big tappable action card. The primary variant fills with brand blue;
/// the secondary variant sits on `surface` with a hairline border.
class _CTACard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool primary;
  final VoidCallback onTap;

  const _CTACard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).tokens;
    final bg = primary ? tokens.primary : tokens.surface;
    final fg = primary ? Colors.white : tokens.onSurface;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(tokens.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radius),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radius),
            border: primary
                ? null
                : Border.all(color: tokens.outlineSoft),
            boxShadow: primary
                ? <BoxShadow>[
                    BoxShadow(
                      color: tokens.primary.withValues(alpha: 0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primary
                      ? Colors.white.withValues(alpha: 0.18)
                      : tokens.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: primary ? Colors.white : tokens.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w600,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: fg.withValues(alpha: primary ? 0.85 : 0.65),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward,
                size: 20,
                color: fg.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionDeniedBlock extends StatelessWidget {
  final BillSplitTokens tokens;
  final String message;
  final VoidCallback onOpenSettings;

  const _PermissionDeniedBlock({
    required Key key,
    required this.tokens,
    required this.message,
    required this.onOpenSettings,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: tokens.warnSurface,
          border: Border.all(color: tokens.warnBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.warning_amber_rounded, color: tokens.warn, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: tokens.warn, fontSize: 13.5),
              ),
            ),
            TextButton(
              onPressed: onOpenSettings,
              child: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
