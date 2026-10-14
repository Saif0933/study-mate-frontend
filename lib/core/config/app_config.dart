import 'package:flutter/foundation.dart';

/// Application configuration using environment variables.
/// Production endpoints and configurations are never hardcoded.
class AppConfig {
  AppConfig._();

  static const String _rawApiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _rawBackendHost = String.fromEnvironment('BACKEND_HOST');
  static const String _rawBackendPort = String.fromEnvironment(
    'BACKEND_PORT',
    defaultValue: '5000',
  );

  static String? _baseUrlOverride;

  /// Sets a runtime override for the API base URL (useful for testing or dynamic environment switching).
  static void setBaseUrlOverride(String? url) {
    _baseUrlOverride = url;
  }

  /// Resolves the effective API base URL.
  /// Precedence:
  /// 1. Runtime override (if set via setBaseUrlOverride)
  /// 2. --dart-define=API_BASE_URL=... (e.g. production/staging full URL)
  /// 3. --dart-define=BACKEND_HOST=... with --dart-define=BACKEND_PORT=... (e.g. physical Android device via LAN IP)
  /// 4. Platform-aware default:
  ///    - Android emulator: http://10.0.2.2:PORT/api/v1
  ///    - Web: http://localhost:PORT/api/v1
  ///    - Desktop / iOS Simulator: http://127.0.0.1:PORT/api/v1
  static String get apiBaseUrl {
    if (_baseUrlOverride != null && _baseUrlOverride!.isNotEmpty) {
      return _baseUrlOverride!;
    }

    if (_rawApiBaseUrl.isNotEmpty) {
      return _rawApiBaseUrl;
    }

    if (kReleaseMode) {
      // In production release builds, never connect to development local loopbacks
      return 'https://api.studymate.ai/api/v1';
    }

    if (_rawBackendHost.isNotEmpty) {
      return 'http://$_rawBackendHost:$_rawBackendPort/api/v1';
    }

    if (kIsWeb) {
      return 'http://localhost:$_rawBackendPort/api/v1';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator loopback IP to access host machine localhost
      return 'http://10.0.2.2:$_rawBackendPort/api/v1';
    }

    // iOS simulator or desktop development (Windows, macOS, Linux)
    return 'http://127.0.0.1:$_rawBackendPort/api/v1';
  }

  /// Default network timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(
    seconds: 45,
  ); // LLM requests can take longer
  static const Duration sendTimeout = Duration(seconds: 30);

  /// Maximum file upload size in bytes (10 MB as per PRD)
  static const int maxUploadSizeBytes = 10 * 1024 * 1024;

  /// App info
  static const String appName = 'AI StudyMate';
  static const String appVersion = '1.0.0';

  /// Support and Legal
  static const String supportEmail = 'support@studymate.ai';
  static const String privacyPolicyUrl = 'https://studymate.ai/privacy';
  static const String termsOfServiceUrl = 'https://studymate.ai/terms';
}
