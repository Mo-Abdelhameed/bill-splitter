import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:bill_split/state/bill_item.dart';

/// Failure categories surfaced by [GeminiExtractor.extract]. Maps directly to
/// the AC-14 failure-mode list in STORY-002.
enum ExtractionFailure {
  /// Lower-level transport problem (DNS, no connectivity, TLS, timeout).
  network,

  /// Gemini responded with a non-2xx HTTP status.
  http,

  /// Response body was not parseable as JSON.
  parse,

  /// JSON parsed but did not match the expected schema (missing fields,
  /// wrong types).
  schema,

  /// Schema valid but the `items` array was empty — treat as a failure per
  /// AC-14 so the user gets a fallback.
  emptyItems,
}

class ExtractionException implements Exception {
  final ExtractionFailure kind;
  final String message;

  ExtractionException(this.kind, [this.message = '']);

  @override
  String toString() => 'ExtractionException(${kind.name}): $message';
}

/// Structured result of a successful extraction call.
class ExtractionResult {
  final List<BillItem> items;
  final double? tax;
  final double? service;

  const ExtractionResult({
    this.items = const <BillItem>[],
    this.tax,
    this.service,
  });

  const ExtractionResult.empty()
      : items = const <BillItem>[],
        tax = null,
        service = null;

  /// Parse a Gemini response payload that already conforms to the AC-3 schema.
  /// Throws [ExtractionException] with [ExtractionFailure.schema] on any
  /// shape mismatch.
  factory ExtractionResult.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'];
    if (itemsJson is! List) {
      throw ExtractionException(
        ExtractionFailure.schema,
        '`items` must be present and a list',
      );
    }

    final items = <BillItem>[];
    for (final entry in itemsJson) {
      if (entry is! Map) {
        throw ExtractionException(
          ExtractionFailure.schema,
          'each item must be a map',
        );
      }
      final name = entry['name'];
      final price = entry['price'];
      if (name is! String) {
        throw ExtractionException(
          ExtractionFailure.schema,
          '`item.name` must be a string',
        );
      }
      if (price is! num) {
        throw ExtractionException(
          ExtractionFailure.schema,
          '`item.price` must be a number',
        );
      }
      items.add(BillItem(name: name, price: price.toDouble()));
    }

    final tax = json['tax'];
    if (tax != null && tax is! num) {
      throw ExtractionException(
        ExtractionFailure.schema,
        '`tax` must be a number or null',
      );
    }

    final service = json['service'];
    if (service != null && service is! num) {
      throw ExtractionException(
        ExtractionFailure.schema,
        '`service` must be a number or null',
      );
    }

    return ExtractionResult(
      items: items,
      tax: (tax as num?)?.toDouble(),
      service: (service as num?)?.toDouble(),
    );
  }
}

/// Abstract interface so the screen can be tested with a fake. The real
/// implementation is [GeminiExtractorImpl].
abstract class GeminiExtractor {
  Future<ExtractionResult> extract(Uint8List imageBytes);
}

/// Real Gemini 2.5 Flash extractor — POSTs the image inline as base64 and asks
/// for a JSON response matching the AC-3 schema.
class GeminiExtractorImpl implements GeminiExtractor {
  final Dio _dio;
  final String _apiKey;
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  GeminiExtractorImpl({Dio? dio, required String apiKey})
      : _dio = dio ?? Dio(),
        _apiKey = apiKey;

  @override
  Future<ExtractionResult> extract(Uint8List imageBytes) async {
    final body = <String, dynamic>{
      'contents': <Map<String, dynamic>>[
        <String, dynamic>{
          'parts': <Map<String, dynamic>>[
            <String, dynamic>{
              'inline_data': <String, dynamic>{
                'mime_type': 'image/jpeg',
                'data': base64Encode(imageBytes),
              },
            },
            <String, dynamic>{
              'text': _systemPrompt,
            },
          ],
        },
      ],
      'generationConfig': <String, dynamic>{
        'responseMimeType': 'application/json',
        'responseSchema': _responseSchema,
      },
    };

    Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        '$_endpoint?key=$_apiKey',
        data: body,
        options: Options(headers: <String, dynamic>{
          'Content-Type': 'application/json',
        }),
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw ExtractionException(ExtractionFailure.network, e.message ?? '');
      }
      throw ExtractionException(ExtractionFailure.http,
          'HTTP ${e.response?.statusCode ?? 'unknown'}: ${e.message ?? ''}');
    }

    if (response.statusCode == null || response.statusCode! ~/ 100 != 2) {
      throw ExtractionException(
        ExtractionFailure.http,
        'status ${response.statusCode}',
      );
    }

    final raw = response.data;
    if (raw is! Map) {
      throw ExtractionException(
        ExtractionFailure.parse,
        'unexpected response body shape',
      );
    }
    final candidates = raw['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw ExtractionException(
        ExtractionFailure.schema,
        'no candidates in Gemini response',
      );
    }
    final parts =
        (candidates.first as Map?)?['content']?['parts'] as List<dynamic>?;
    final textPart = parts?.firstWhere(
      (dynamic p) => p is Map && p['text'] is String,
      orElse: () => null,
    );
    final text = (textPart as Map?)?['text'] as String?;
    if (text == null) {
      throw ExtractionException(
        ExtractionFailure.schema,
        'no text part in Gemini response',
      );
    }

    final Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw ExtractionException(ExtractionFailure.parse,
          'inner JSON could not be decoded');
    }

    final result = ExtractionResult.fromJson(parsed);
    if (result.items.isEmpty) {
      throw ExtractionException(
        ExtractionFailure.emptyItems,
        'Gemini returned no items',
      );
    }
    return result;
  }
}

const String _systemPrompt = '''
You are a receipt parser. Extract every line item from the receipt image.
Return ONLY valid JSON matching the provided schema.
- List one entry per single unit of purchase. If a receipt shows "3 x Coke = 90",
  return three separate entries each with price 30.
- Receipts may be in Arabic, English, or mixed. Keep names in the original language.
- `tax` is the numeric tax amount listed on the receipt, or null if no tax line is present.
- `service` is the numeric service-charge amount listed on the receipt, or null if not present.
- Do NOT include subtotal, total, tax, or service as items in the items list.
''';

final Map<String, dynamic> _responseSchema = <String, dynamic>{
  'type': 'object',
  'properties': <String, dynamic>{
    'items': <String, dynamic>{
      'type': 'array',
      'items': <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'name': <String, dynamic>{'type': 'string'},
          'price': <String, dynamic>{'type': 'number'},
        },
        'required': <String>['name', 'price'],
      },
    },
    'tax': <String, dynamic>{
      'type': <String>['number', 'null'],
    },
    'service': <String, dynamic>{
      'type': <String>['number', 'null'],
    },
  },
  'required': <String>['items', 'tax', 'service'],
};
