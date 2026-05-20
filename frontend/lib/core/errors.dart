import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

class BackendError implements Exception {
  BackendError(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => 'BackendError($code: $message)';
}

class NetworkError implements Exception {
  NetworkError(this.cause);
  final Object cause;
  @override
  String toString() => 'NetworkError($cause)';
}

Object mapDioError(DioException err) {
  final data = err.response?.data;
  if (data is Map && data['error'] is Map) {
    final body = data['error'] as Map;
    final code = (body['code'] ?? 'INTERNAL').toString();
    final message = (body['message'] ?? '').toString();
    return BackendError(code, message);
  }
  return NetworkError(err);
}

String describeError(BuildContext context, Object err) {
  final l = AppLocalizations.of(context)!;
  if (err is BackendError) {
    switch (err.code) {
      case 'INVALID_IMAGE':
        return l.invalidImage;
      case 'IMAGE_TOO_LARGE':
        return l.imageTooLarge;
      case 'EXTRACTION_FAILED':
      case 'EXTRACTION_UNAVAILABLE':
        return l.extractionFailed;
      default:
        return err.message.isNotEmpty ? err.message : l.extractionFailed;
    }
  }
  if (err is NetworkError) return l.networkError;
  return l.extractionFailed;
}
