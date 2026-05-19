import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:bill_split/services/image_acquirer.dart';
import 'package:bill_split/services/image_resizer.dart';
import 'package:bill_split/state/bill_state.dart';

/// STORY-003: image acquisition. Two CTAs (camera + gallery), preview state
/// after acquire, inline permission-denied errors, and a "no image selected"
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
      appBar: AppBar(title: const Text('Capture receipt')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: switch (_phase) {
            _Phase.pre => _buildInitial(),
            _Phase.preview => _buildPreview(),
          },
        ),
      ),
    );
  }

  Widget _buildInitial() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _onTakePhoto,
          icon: const Icon(Icons.photo_camera),
          label: const Text('Take Photo'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(64),
          ),
        ),
        if (_cameraDenied)
          _PermissionDeniedBlock(
            key: const ValueKey<String>('camera-permission-error'),
            message: 'Camera permission denied.',
            onOpenSettings: () => widget.acquirer.openAppSettings(),
          ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _onPickFromGallery,
          icon: const Icon(Icons.photo_library),
          label: const Text('Pick from Gallery'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(64),
          ),
        ),
        if (_galleryDenied)
          _PermissionDeniedBlock(
            key: const ValueKey<String>('gallery-permission-error'),
            message: 'Photo library permission denied.',
            onOpenSettings: () => widget.acquirer.openAppSettings(),
          ),
      ],
    );
  }

  Widget _buildPreview() {
    final bytes = widget.billState.imageBytes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: bytes == null
              ? const SizedBox.shrink()
              : Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (BuildContext context, Object error,
                          StackTrace? stack) =>
                      const Icon(Icons.broken_image, size: 64),
                ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _onUseThisPhoto,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('Use this photo'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _onRetake,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('Retake or repick'),
        ),
      ],
    );
  }
}

class _PermissionDeniedBlock extends StatelessWidget {
  final String message;
  final VoidCallback onOpenSettings;

  const _PermissionDeniedBlock({
    required Key key,
    required this.message,
    required this.onOpenSettings,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red),
            ),
          ),
          TextButton(
            onPressed: onOpenSettings,
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
