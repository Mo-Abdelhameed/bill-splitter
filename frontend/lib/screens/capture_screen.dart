import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/receipt_api.dart';
import '../main.dart';
import 'diners_screen.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  bool _loading = false;
  String? _error;

  static const _backendUrl =
      String.fromEnvironment('BACKEND_URL', defaultValue: 'http://localhost:9090');

  Future<void> _pickAndExtract(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    await _runExtract(File(picked.path));
  }

  Future<void> _runExtract(File file) async {
    final session = SessionScope.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ReceiptApi(baseUrl: _backendUrl);
      final receipt = await api.extract(file);
      if (!mounted) return;
      session.setReceipt(receipt);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const DinersScreen(),
      ));
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _useMock() async {
    final session = SessionScope.of(context);
    session.setReceipt(buildMockReceipt());
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const DinersScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bill Splitter')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(
              'Snap a receipt to start splitting.',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loading ? null : () => _pickAndExtract(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take photo'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loading ? null : () => _pickAndExtract(ImageSource.gallery),
              icon: const Icon(Icons.photo),
              label: const Text('Pick from gallery'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loading ? null : _useMock,
              icon: const Icon(Icons.science),
              label: const Text('Use sample receipt'),
            ),
            const SizedBox(height: 24),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
