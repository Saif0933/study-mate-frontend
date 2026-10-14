import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_mate_frontend/core/errors/error_mapper.dart';
import 'package:study_mate_frontend/core/network/api_exceptions.dart';
import 'package:study_mate_frontend/core/utils/validators.dart';

void main() {
  group('Validators Unit Tests (Phase 1)', () {
    test('required validator detects null and empty inputs', () {
      expect(Validators.required(null), isNotNull);
      expect(Validators.required(''), isNotNull);
      expect(Validators.required('   '), isNotNull);
      expect(Validators.required('hello'), isNull);
    });

    test('email validator verifies proper email format', () {
      expect(Validators.email(null), isNotNull);
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('invalid-email'), isNotNull);
      expect(Validators.email('user@domain'), isNotNull);
      expect(Validators.email('user@example.com'), isNull);
    });

    test('password validator enforces minimum length', () {
      expect(Validators.password(null), isNotNull);
      expect(Validators.password(''), isNotNull);
      expect(Validators.password('12345', minLength: 6), isNotNull);
      expect(Validators.password('123456', minLength: 6), isNull);
      expect(Validators.password('strongpassword123'), isNull);
    });

    test('confirmPassword matches identical strings', () {
      expect(Validators.confirmPassword(null, 'secret'), isNotNull);
      expect(Validators.confirmPassword('other', 'secret'), isNotNull);
      expect(Validators.confirmPassword('secret', 'secret'), isNull);
    });

    test('combine runs validators in sequence', () {
      String? combined(String? v) =>
          Validators.combine(v, [Validators.required, Validators.email]);

      expect(combined(''), contains('required'));
      expect(combined('not-an-email'), contains('valid email'));
      expect(combined('test@domain.com'), isNull);
    });
  });

  group('ErrorMapper Unit Tests (Phase 1)', () {
    test('Maps ApiException with proper titles and retryability', () {
      const authErr = ApiException(
        code: 'AUTH_REQUIRED',
        message: 'Please log in',
      );
      final mappedAuth = ErrorMapper.map(authErr);
      expect(mappedAuth.title, 'Authentication Required');
      expect(mappedAuth.code, 'AUTH_REQUIRED');
      expect(mappedAuth.isRetryable, false);

      const rateErr = ApiException(code: 'RATE_LIMITED', message: 'Slow down');
      final mappedRate = ErrorMapper.map(rateErr);
      expect(mappedRate.title, 'Rate Limit Exceeded');
      expect(mappedRate.isRetryable, true);
    });

    test('Maps DioException network and timeout types', () {
      final timeoutErr = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      );
      final mappedTimeout = ErrorMapper.map(timeoutErr);
      expect(mappedTimeout.code, 'TIMEOUT_ERROR');
      expect(mappedTimeout.isRetryable, true);

      final offlineErr = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionError,
      );
      final mappedOffline = ErrorMapper.map(offlineErr);
      expect(mappedOffline.code, 'NETWORK_ERROR');
      expect(mappedOffline.isRetryable, true);
    });

    test('Maps SocketException gracefully', () {
      const socketErr = SocketException('Failed host lookup');
      final mapped = ErrorMapper.map(socketErr);
      expect(mapped.code, 'SOCKET_EXCEPTION');
      expect(mapped.isRetryable, true);
    });
  });
}
