import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/models.dart';

class ReceiptApi {
  ReceiptApi({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<ExtractedReceipt> extract(File image) async {
    final uri = Uri.parse('$baseUrl/extract');
    final req = http.MultipartRequest('POST', uri);
    req.files.add(await http.MultipartFile.fromPath('image', image.path));
    final streamed = await _client.send(req);
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 200) {
      throw Exception('Extract failed: ${resp.statusCode} ${resp.body}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return ExtractedReceipt.fromJson(json);
  }
}

/// Mock used when the user opts to skip the live backend (e.g. no API key).
ExtractedReceipt buildMockReceipt() {
  return ExtractedReceipt.fromJson({
    'items': [
      {'name': 'Margherita Pizza', 'price': 14.0, 'quantity': 1},
      {'name': 'Caesar Salad', 'price': 10.0, 'quantity': 1},
      {'name': 'Sparkling Water', 'price': 4.0, 'quantity': 1},
      {'name': 'Tiramisu', 'price': 8.0, 'quantity': 1},
    ],
    'charges': {'tax': 2.88, 'service': 4.32},
    'subtotal': 36.0,
    'total': 43.2,
    'currency': 'USD',
  });
}
