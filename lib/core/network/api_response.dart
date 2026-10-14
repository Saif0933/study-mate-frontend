/// Standard backend API envelope from PRD 13.2
class ApiResponse<T> {
  final T? data;
  final ApiMeta? meta;
  final ApiErrorPayload? error;

  const ApiResponse({this.data, this.meta, this.error});

  bool get isSuccess => error == null && data != null;
  bool get hasError => error != null;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic rawData) fromData,
  ) {
    return ApiResponse<T>(
      data: json['data'] != null ? fromData(json['data']) : null,
      meta: json['meta'] != null
          ? ApiMeta.fromJson(json['meta'] as Map<String, dynamic>)
          : null,
      error: json['error'] != null
          ? ApiErrorPayload.fromJson(json['error'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ApiMeta {
  final String? requestId;
  final String? model;
  final int? total;
  final int? page;
  final int? limit;

  const ApiMeta({
    this.requestId,
    this.model,
    this.total,
    this.page,
    this.limit,
  });

  factory ApiMeta.fromJson(Map<String, dynamic> json) {
    return ApiMeta(
      requestId: json['requestId'] as String?,
      model: json['model'] as String?,
      total: json['total'] as int?,
      page: json['page'] as int?,
      limit: json['limit'] as int?,
    );
  }
}

class ApiErrorPayload {
  final String code;
  final String message;
  final String? requestId;

  const ApiErrorPayload({
    required this.code,
    required this.message,
    this.requestId,
  });

  factory ApiErrorPayload.fromJson(Map<String, dynamic> json) {
    return ApiErrorPayload(
      code: (json['code'] as String?) ?? 'UNKNOWN_ERROR',
      message: (json['message'] as String?) ?? 'Unknown error occurred',
      requestId: json['requestId'] as String?,
    );
  }
}
