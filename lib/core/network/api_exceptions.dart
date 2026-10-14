/// Standard application exceptions mapped from PRD error codes.
class ApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;
  final String? requestId;

  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.requestId,
  });

  /// True if the user can retry immediately or after a short delay
  bool get isRetryable =>
      code == 'RATE_LIMITED' ||
      code == 'NETWORK_ERROR' ||
      code == 'CONNECTION_REFUSED' ||
      code == 'TIMEOUT_ERROR' ||
      code == 'AI_PROVIDER_UNAVAILABLE';

  /// True if authentication is required or session expired
  bool get isAuthError => code == 'AUTH_REQUIRED' || statusCode == 401;

  @override
  String toString() =>
      'ApiException(code: $code, message: $message, status: $statusCode, req: $requestId)';
}

/// Helper to parse backend error payload into typed ApiException
ApiException parseApiError({dynamic errorBody, int? statusCode}) {
  String code = 'UNKNOWN_ERROR';
  String message = 'An unexpected error occurred. Please try again.';
  String? requestId;

  if (errorBody is Map<String, dynamic>) {
    final errObj = errorBody['error'];
    final metaObj = errorBody['meta'];

    if (metaObj is Map<String, dynamic> && metaObj['requestId'] is String) {
      requestId = metaObj['requestId'] as String;
    }

    if (errObj is Map<String, dynamic>) {
      code = (errObj['code'] as String?) ?? code;
      message = (errObj['message'] as String?) ?? message;
      requestId = (errObj['requestId'] as String?) ?? requestId;
    } else if (errorBody['message'] is String) {
      message = errorBody['message'] as String;
    }
  } else if (statusCode == 401) {
    code = 'AUTH_REQUIRED';
    message = 'Authentication required. Please sign in again.';
  } else if (statusCode == 403) {
    code = 'FORBIDDEN';
    message = 'You do not have permission to access this resource.';
  } else if (statusCode == 404) {
    code = 'RESOURCE_NOT_FOUND';
    message = 'The requested resource was not found.';
  } else if (statusCode == 429) {
    code = 'RATE_LIMITED';
    message = 'Too many requests. Please slow down and try again.';
  } else if (statusCode != null && statusCode >= 500) {
    code = 'INTERNAL_ERROR';
    message = 'A server error occurred. Please try again shortly.';
  }

  return ApiException(
    code: code,
    message: message,
    statusCode: statusCode,
    requestId: requestId,
  );
}
