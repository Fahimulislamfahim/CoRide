import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:flutter/foundation.dart';

class ApiService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    webOptions: WebOptions(
      dbName: 'CoRideStorage',
      publicKey: 'CoRidePubKey',
    ),
  );
  
  // Render Free Tier URL (fallback to local machine IP for emulator testing)
  // For android emulators, 10.0.2.2 points to localhost of host machine.
  static const String baseUrl = kIsWeb ? 'http://localhost:5000/api' : 'http://10.0.2.2:5000/api'; 
  // Update this to your deployed Render URL in production, e.g. 'https://coride-backend.onrender.com/api'

  ApiService() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
    
    // Attach Interceptor for automatic JWT handling
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'jwt_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          options.headers['Content-Type'] = 'application/json';
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          // Format standard errors
          String errorMessage = 'An unexpected error occurred';
          if (e.response != null && e.response?.data != null) {
            if (e.response?.data is Map && e.response?.data['error'] != null) {
              errorMessage = e.response?.data['error'];
            }
          } else {
            if (e.type == DioExceptionType.connectionTimeout) {
              errorMessage = 'Connection timeout. Please check your internet connection.';
            } else if (e.type == DioExceptionType.connectionError) {
              errorMessage = 'Unable to connect to server. Render service may be starting up.';
            }
          }
          
          // Propagate formatted message in error object
          final modifiedError = DioException(
            requestOptions: e.requestOptions,
            response: e.response,
            type: e.type,
            error: errorMessage,
          );
          return handler.next(modifiedError);
        },
      ),
    );
  }

  // HTTP Helper Methods
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw e.error ?? 'Get request failed';
    }
  }

  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      throw e.error ?? 'Post request failed';
    }
  }

  Future<Response> patch(String path, {dynamic data}) async {
    try {
      return await _dio.patch(path, data: data);
    } on DioException catch (e) {
      throw e.error ?? 'Patch request failed';
    }
  }

  // Token storage utilities
  Future<void> saveToken(String token) async {
    await _storage.write(key: 'jwt_token', value: token);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: 'jwt_token');
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }
}
