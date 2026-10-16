import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../storage/secure_storage_service.dart';
import 'api_exceptions.dart';
import 'auth_interceptor.dart';

/// Central API client using Dio for all backend HTTP communications.
class ApiClient {
  late final Dio dio;
  final SecureStorageService storageService;

  ApiClient({
    required this.storageService,
    Dio? customDio,
    void Function()? onUnauthorized,
  }) {
    dio =
        customDio ??
        Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: AppConfig.connectTimeout,
            receiveTimeout: AppConfig.receiveTimeout,
            sendTimeout: AppConfig.sendTimeout,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

    // Ensure AuthInterceptor is not registered twice if already present on customDio
    final hasAuthInterceptor = dio.interceptors.any((i) => i is AuthInterceptor);
    if (!hasAuthInterceptor) {
      dio.interceptors.add(
        AuthInterceptor(
          storageService: storageService,
          onUnauthorized: onUnauthorized,
        ),
      );
    }
  }

  /// Perform a GET request
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return _extractData(response);
    } on DioException catch (e) {
      if (_isConnectionError(e) &&
          !kReleaseMode &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android) {
        final fallback = await _attemptFallback(
          method: 'GET',
          path: path,
          queryParameters: queryParameters,
          options: options,
        );
        if (fallback != null) {
          return _extractData(fallback);
        }
      }
      throw _handleDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(code: 'CLIENT_ERROR', message: e.toString());
    }
  }

  /// Perform a POST request
  Future<dynamic> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return _extractData(response);
    } on DioException catch (e) {
      if (_isConnectionError(e) &&
          !kReleaseMode &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android) {
        final fallback = await _attemptFallback(
          method: 'POST',
          path: path,
          data: data,
          queryParameters: queryParameters,
          options: options,
        );
        if (fallback != null) {
          return _extractData(fallback);
        }
      }
      throw _handleDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(code: 'CLIENT_ERROR', message: e.toString());
    }
  }

  /// Perform a PATCH request
  Future<dynamic> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return _extractData(response);
    } on DioException catch (e) {
      if (_isConnectionError(e) &&
          !kReleaseMode &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android) {
        final fallback = await _attemptFallback(
          method: 'PATCH',
          path: path,
          data: data,
          queryParameters: queryParameters,
          options: options,
        );
        if (fallback != null) {
          return _extractData(fallback);
        }
      }
      throw _handleDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(code: 'CLIENT_ERROR', message: e.toString());
    }
  }

  /// Perform a DELETE request
  Future<dynamic> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return _extractData(response);
    } on DioException catch (e) {
      if (_isConnectionError(e) &&
          !kReleaseMode &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android) {
        final fallback = await _attemptFallback(
          method: 'DELETE',
          path: path,
          data: data,
          queryParameters: queryParameters,
          options: options,
        );
        if (fallback != null) {
          return _extractData(fallback);
        }
      }
      throw _handleDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(code: 'CLIENT_ERROR', message: e.toString());
    }
  }

  /// Upload file using multipart/form-data
  Future<dynamic> uploadFile(
    String path, {
    required File file,
    required String fileFieldName,
    String? customFileName,
    Map<String, dynamic>? extraFields,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      final fileName =
          customFileName ?? file.path.split(RegExp(r'[/\\]')).last;
      final formData = FormData.fromMap({
        fileFieldName: await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
        ...?extraFields,
      });

      final response = await dio.post(
        path,
        data: formData,
        onSendProgress: onSendProgress,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );
      return _extractData(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(code: 'CLIENT_ERROR', message: e.toString());
    }
  }

  dynamic _extractData(Response response) {
    final body = response.data;
    if (body is Map<String, dynamic>) {
      // Check if wrapped in PRD envelope
      if (body.containsKey('error') && body['error'] != null) {
        throw parseApiError(errorBody: body, statusCode: response.statusCode);
      }
      if (body.containsKey('data')) {
        return body['data'];
      }
    }
    return body;
  }

  ApiException _handleDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const ApiException(
        code: 'TIMEOUT_ERROR',
        message:
            'The connection timed out. Please check your internet connection.',
      );
    }

    if (_isConnectionError(error)) {
      return ApiException(
        code: 'CONNECTION_REFUSED',
        message:
            'Unable to connect to the backend server at ${dio.options.baseUrl}. '
            'Please verify the backend is running and reachable.',
      );
    }

    if (error.error is FormatException) {
      return const ApiException(
        code: 'INVALID_JSON',
        message: 'Received an invalid or malformed JSON response from the server.',
      );
    }

    if (error.response != null) {
      return parseApiError(
        errorBody: error.response?.data,
        statusCode: error.response?.statusCode,
      );
    }

    return ApiException(
      code: 'UNKNOWN_NETWORK_ERROR',
      message: error.message ?? 'A network communication error occurred.',
    );
  }

  bool _isConnectionError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return true;
    }

    final errStr = (error.error?.toString() ?? '').toLowerCase();
    final msgStr = (error.message ?? '').toLowerCase();

    return error.error is SocketException ||
        errStr.contains('socketexception') ||
        errStr.contains('refused') ||
        errStr.contains('failed host lookup') ||
        errStr.contains('network is unreachable') ||
        msgStr.contains('connection refused') ||
        msgStr.contains('socketexception');
  }

  Future<Response<dynamic>?> _attemptFallback({
    required String method,
    required String path,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final currentBase = dio.options.baseUrl;
    final candidates = AppConfig.candidateBaseUrls;

    for (final candidate in candidates) {
      if (candidate == currentBase) continue;

      try {
        final probeDio = Dio(
          BaseOptions(
            baseUrl: candidate,
            connectTimeout: const Duration(seconds: 2),
            receiveTimeout: const Duration(seconds: 2),
          ),
        );
        final healthRes = await probeDio.get('/health');
        if (healthRes.statusCode == 200) {
          dio.options.baseUrl = candidate;
          AppConfig.setBaseUrlOverride(candidate);

          return await dio.request(
            path,
            data: data,
            queryParameters: queryParameters,
            options: (options ?? Options()).copyWith(method: method),
          );
        }
      } catch (_) {
        // Try next candidate
      }
    }
    return null;
  }
}
