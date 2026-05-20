import 'dart:async';

import 'package:dio/dio.dart';

/// Returns the current Firebase Anonymous Auth ID token (or null if no user
/// is signed in). Injected so this client can be tested without Firebase.
typedef IdTokenProvider = Future<String?> Function();

/// Thin wrapper around [Dio] that attaches the Firebase ID token to every
/// outgoing request. The base URL is supplied at construction (typically
/// from `--dart-define=BACKEND_URL` in main.dart).
class BackendClient {
  /// Dio instance, exposed so service classes (e.g. [BackendExtractionClient])
  /// can call `.post(...)` directly.
  final Dio dio;

  BackendClient({
    required String baseUrl,
    required IdTokenProvider idTokenProvider,
    Dio? dio,
  }) : dio = dio ?? Dio() {
    this.dio.options
      ..baseUrl = baseUrl
      ..connectTimeout = const Duration(seconds: 30)
      ..receiveTimeout = const Duration(seconds: 30);

    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
          final String? token = await idTokenProvider();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  /// Default base URL for local dev (uvicorn on port 9090; see `make backend-run`).
  /// Production builds inject `--dart-define=BACKEND_URL=https://...` to override.
  static const String defaultLocalBaseUrl = 'http://localhost:9090/v1';
}
