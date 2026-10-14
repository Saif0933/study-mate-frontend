import 'dart:io';
import 'package:dio/dio.dart';
import '../network/api_exceptions.dart';
import 'app_failure.dart';

/// Central error mapper translating technical exceptions to user-facing AppFailures.
class ErrorMapper {
  ErrorMapper._();

  static AppFailure map(dynamic error) {
    if (error is ApiException) {
      return AppFailure(
        title: _getTitleForCode(error.code),
        message: error.message,
        code: error.code,
        isRetryable: error.isRetryable,
        originalError: error,
      );
    }

    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return const AppFailure(
            title: 'Connection Timeout',
            message:
                'Server took too long to respond. Please check your connection and retry.',
            code: 'TIMEOUT_ERROR',
            isRetryable: true,
          );

        case DioExceptionType.connectionError:
          return const AppFailure(
            title: 'Network Offline',
            message:
                'Unable to reach the server. Please verify your internet connection.',
            code: 'NETWORK_ERROR',
            isRetryable: true,
          );

        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final errorData = error.response?.data;
          final parsed = parseApiError(
            errorBody: errorData,
            statusCode: statusCode,
          );
          return map(parsed);

        case DioExceptionType.cancel:
          return const AppFailure(
            title: 'Request Cancelled',
            message: 'The request was cancelled before completion.',
            code: 'REQUEST_CANCELLED',
            isRetryable: false,
          );

        case DioExceptionType.badCertificate:
          return const AppFailure(
            title: 'Security Warning',
            message: 'SSL/TLS certificate verification failed.',
            code: 'BAD_CERTIFICATE',
            isRetryable: false,
          );

        case DioExceptionType.unknown:
          if (error.error is SocketException) {
            return const AppFailure(
              title: 'No Internet Connection',
              message:
                  'Check your Wi-Fi or mobile data connection and try again.',
              code: 'SOCKET_EXCEPTION',
              isRetryable: true,
            );
          }
          return AppFailure(
            title: 'Unexpected Network Error',
            message: error.message ?? 'An unexpected network error occurred.',
            code: 'UNKNOWN_NETWORK_ERROR',
            isRetryable: true,
            originalError: error,
          );

        default:
          return AppFailure(
            title: 'Network Error',
            message: error.message ?? 'A network communication error occurred.',
            code: 'DIO_ERROR',
            isRetryable: true,
            originalError: error,
          );
      }
    }

    if (error is SocketException) {
      return const AppFailure(
        title: 'Connection Error',
        message: 'Could not connect to the server. Please try again later.',
        code: 'SOCKET_EXCEPTION',
        isRetryable: true,
      );
    }

    if (error is FormatException) {
      return const AppFailure(
        title: 'Data Format Error',
        message: 'Unexpected data received from the service.',
        code: 'FORMAT_ERROR',
        isRetryable: false,
      );
    }

    return AppFailure(
      title: 'Unexpected Error',
      message: error?.toString() ?? 'Something went wrong. Please try again.',
      code: 'UNKNOWN_ERROR',
      isRetryable: true,
      originalError: error,
    );
  }

  static String _getTitleForCode(String code) {
    switch (code) {
      case 'AUTH_REQUIRED':
      case 'INVALID_CREDENTIALS':
        return 'Authentication Required';
      case 'FORBIDDEN':
        return 'Access Denied';
      case 'RESOURCE_NOT_FOUND':
        return 'Not Found';
      case 'RATE_LIMITED':
        return 'Rate Limit Exceeded';
      case 'NETWORK_ERROR':
      case 'TIMEOUT_ERROR':
        return 'Connection Problem';
      case 'AI_PROVIDER_UNAVAILABLE':
        return 'AI Service Busy';
      case 'VALIDATION_ERROR':
        return 'Invalid Input';
      default:
        return 'Error';
    }
  }
}
