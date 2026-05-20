import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:bill_split/services/backend_client.dart';
import 'package:bill_split/state/bill_item.dart';

/// Failure categories surfaced by [ExtractionClient.extract]. Maps directly
/// to the backend error codes in `contracts/backend-api-v1.md`.
enum ExtractionFailure {
  /// Lower-level transport problem (DNS, no connectivity, TLS, timeout).
  network,

  /// Backend (or Gemini through it) returned a non-2xx response.
  http,

  /// Response body was not parseable as JSON.
  parse,

  /// JSON parsed but did not match the expected schema (missing fields,
  /// wrong types).
  schema,

  /// Schema valid but the `items` array was empty — treat as a failure so
  /// the user gets the manual-fallback UI.
  emptyItems,

  /// The backend rejected the Firebase ID token (401). The UI should prompt
  /// the user to re-authenticate.
  unauthorized,
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
}

/// Abstract interface so screens can be tested with a fake. The real
/// implementation is [BackendExtractionClient].
abstract class ExtractionClient {
  Future<ExtractionResult> extract(Uint8List imageBytes);
}

/// Real implementation that calls the backend's `POST /v1/extract` endpoint.
/// The Firebase ID token is attached by [BackendClient]'s interceptor.
class BackendExtractionClient implements ExtractionClient {
  final BackendClient _backend;

  BackendExtractionClient(this._backend);

  @override
  Future<ExtractionResult> extract(Uint8List imageBytes) async {
    Response<dynamic> response;
    try {
      response = await _backend.dio.post<dynamic>(
        '/extract',
        data: FormData.fromMap(<String, dynamic>{
          'image': MultipartFile.fromBytes(imageBytes, filename: 'receipt.jpg'),
        }),
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }

    final body = response.data;
    if (body is! Map) {
      throw ExtractionException(
        ExtractionFailure.parse,
        'unexpected response body shape',
      );
    }
    return _parseBody(body);
  }

  ExtractionException _mapDioError(DioException e) {
    final int? code = e.response?.statusCode;
    if (code == 401) {
      return ExtractionException(ExtractionFailure.unauthorized, e.message ?? '');
    }
    final dynamic backendError = (e.response?.data is Map)
        ? (e.response?.data as Map)['error']
        : null;
    if (backendError is String) {
      switch (backendError) {
        case 'unauthorized':
          return ExtractionException(ExtractionFailure.unauthorized, e.message ?? '');
        case 'bad_image':
        case 'image_too_large':
        case 'parse':
          return ExtractionException(ExtractionFailure.parse, e.message ?? '');
        case 'schema':
          return ExtractionException(ExtractionFailure.schema, e.message ?? '');
        case 'empty':
          return ExtractionException(ExtractionFailure.emptyItems, e.message ?? '');
        case 'network':
          return ExtractionException(ExtractionFailure.network, e.message ?? '');
        case 'http':
          return ExtractionException(ExtractionFailure.http, e.message ?? '');
      }
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return ExtractionException(ExtractionFailure.network, e.message ?? '');
    }
    return ExtractionException(
      ExtractionFailure.http,
      'HTTP ${code ?? 'unknown'}: ${e.message ?? ''}',
    );
  }

  ExtractionResult _parseBody(Map<dynamic, dynamic> json) {
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
        throw ExtractionException(ExtractionFailure.schema, 'each item must be a map');
      }
      final name = entry['name'];
      final price = entry['price'];
      if (name is! String) {
        throw ExtractionException(ExtractionFailure.schema, '`item.name` must be a string');
      }
      if (price is! num) {
        throw ExtractionException(ExtractionFailure.schema, '`item.price` must be a number');
      }
      items.add(BillItem(name: name, price: price.toDouble()));
    }
    if (items.isEmpty) {
      throw ExtractionException(
        ExtractionFailure.emptyItems,
        'backend returned no items',
      );
    }
    final tax = json['tax'];
    if (tax != null && tax is! num) {
      throw ExtractionException(ExtractionFailure.schema, '`tax` must be a number or null');
    }
    final service = json['service'];
    if (service != null && service is! num) {
      throw ExtractionException(ExtractionFailure.schema, '`service` must be a number or null');
    }
    return ExtractionResult(
      items: items,
      tax: (tax as num?)?.toDouble(),
      service: (service as num?)?.toDouble(),
    );
  }
}
