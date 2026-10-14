import 'package:flutter_test/flutter_test.dart';
import 'package:study_mate_frontend/core/network/api_exceptions.dart';
import 'package:study_mate_frontend/core/network/api_response.dart';

void main() {
  group('ApiResponse Envelope Tests (PRD 13.2)', () {
    test('successfully parses success response with data and meta', () {
      final json = {
        'data': {'id': 'test-123', 'title': 'Sample Quiz'},
        'meta': {
          'requestId': 'req-abc-999',
          'model': 'gpt-4o-mini',
          'total': 1,
        },
        'error': null,
      };

      final response = ApiResponse.fromJson(
        json,
        (raw) => raw as Map<String, dynamic>,
      );

      expect(response.isSuccess, isTrue);
      expect(response.hasError, isFalse);
      expect(response.data!['id'], equals('test-123'));
      expect(response.meta?.requestId, equals('req-abc-999'));
      expect(response.meta?.model, equals('gpt-4o-mini'));
    });

    test('parses error payload correctly', () {
      final json = {
        'data': null,
        'meta': {'requestId': 'req-err-456'},
        'error': {
          'code': 'QUOTA_EXCEEDED',
          'message': 'AI usage quota has been exceeded for today.',
          'requestId': 'req-err-456',
        },
      };

      final response = ApiResponse<Map<String, dynamic>>.fromJson(
        json,
        (raw) => raw as Map<String, dynamic>,
      );

      expect(response.isSuccess, isFalse);
      expect(response.hasError, isTrue);
      expect(response.error?.code, equals('QUOTA_EXCEEDED'));
      expect(response.error?.message, contains('AI usage quota'));
    });
  });

  group('ApiException Parser Tests (PRD Appendix B)', () {
    test('parses 401 as AUTH_REQUIRED', () {
      final exc = parseApiError(statusCode: 401);
      expect(exc.code, equals('AUTH_REQUIRED'));
      expect(exc.isAuthError, isTrue);
    });

    test('parses 429 as RATE_LIMITED', () {
      final exc = parseApiError(statusCode: 429);
      expect(exc.code, equals('RATE_LIMITED'));
      expect(exc.isRetryable, isTrue);
    });

    test('parses custom backend error payload', () {
      final payload = {
        'error': {
          'code': 'DOCUMENT_NOT_READY',
          'message': 'PDF is still processing embeddings.',
        },
        'meta': {'requestId': 'req-doc-789'},
      };

      final exc = parseApiError(errorBody: payload, statusCode: 400);
      expect(exc.code, equals('DOCUMENT_NOT_READY'));
      expect(exc.message, equals('PDF is still processing embeddings.'));
      expect(exc.requestId, equals('req-doc-789'));
    });
  });
}
