import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;

import '../../../core/errors.dart';
import '../model/item.dart';

class ExtractResult {
  ExtractResult({required this.items, this.taxAmount, this.serviceAmount});
  final List<Item> items;
  final num? taxAmount;
  final num? serviceAmount;
}

abstract class ExtractRepository {
  Future<ExtractResult> extract(Uint8List rawImageBytes);
}

class HttpExtractRepository implements ExtractRepository {
  HttpExtractRepository(this._dio);
  final Dio _dio;

  static const int _maxLongEdge = 2000;
  static const int _jpegQuality = 85;

  @override
  Future<ExtractResult> extract(Uint8List rawImageBytes) async {
    final compressed = _compress(rawImageBytes);

    try {
      final form = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          compressed,
          filename: 'bill.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        ),
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/extract',
        data: form,
      );
      final data = response.data!;
      final itemsRaw = (data['items'] as List?) ?? const [];
      final items = itemsRaw
          .cast<Map<String, dynamic>>()
          .map((m) => Item.create(
                name: m['name'] as String,
                quantity: (m['quantity'] as num).toInt(),
                unitPrice: m['unit_price'] as num,
                source: ItemSource.extracted,
              ))
          .toList();
      return ExtractResult(
        items: items,
        taxAmount: data['tax_amount'] as num?,
        serviceAmount: data['service_amount'] as num?,
      );
    } on DioException catch (err) {
      throw mapDioError(err);
    }
  }

  Uint8List _compress(Uint8List input) {
    final decoded = img.decodeImage(input);
    if (decoded == null) return input;
    final longEdge = decoded.width > decoded.height ? decoded.width : decoded.height;
    final resized = longEdge > _maxLongEdge
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? _maxLongEdge : null,
            height: decoded.height > decoded.width ? _maxLongEdge : null,
          )
        : decoded;
    return Uint8List.fromList(img.encodeJpg(resized, quality: _jpegQuality));
  }
}
