/// Unified failure representation for UI and domain layers.
class AppFailure {
  final String title;
  final String message;
  final String? code;
  final bool isRetryable;
  final dynamic originalError;

  const AppFailure({
    required this.message,
    this.title = 'Error',
    this.code,
    this.isRetryable = false,
    this.originalError,
  });

  @override
  String toString() =>
      'AppFailure(title: $title, code: $code, message: $message, isRetryable: $isRetryable)';
}
