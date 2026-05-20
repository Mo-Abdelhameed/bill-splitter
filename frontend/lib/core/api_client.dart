import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

Dio buildApiClient({FirebaseAuth? auth}) {
  final firebase = auth ?? FirebaseAuth.instance;
  final dio = Dio(
    BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final user = firebase.currentUser;
        if (user != null) {
          final token = await user.getIdToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
    ),
  );

  return dio;
}
