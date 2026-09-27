import 'package:flutter/foundation.dart';

/// Backend base URL configuration:
/// - In Debug mode (kDebugMode): defaults to local Docker (http://localhost:8080)
/// - In Release/Production mode: defaults to https://server.dsmagic.com
/// - Override at build/run time:
///   flutter run --dart-define=MWAVULI_API=https://server.dsmagic.com
class ApiConfig {
  static String get baseUrl {
    const customApi = String.fromEnvironment('MWAVULI_API');
    if (customApi.isNotEmpty) {
      return customApi;
    }
    if (kDebugMode) {
      // Local Docker backend URL (127.0.0.1 matches adb reverse IPv4)
      return 'http://127.0.0.1:8080';
    }
    // Production server URL
    return 'https://server.dsmagic.com';
  }

  static const String appVersion =
      String.fromEnvironment('MWAVULI_VERSION', defaultValue: '0.1.1');
}
