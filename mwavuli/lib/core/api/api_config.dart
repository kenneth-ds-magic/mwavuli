/// Backend base URL. Override at build time:
///   flutter run --dart-define=MWAVULI_API=https://api.mwavuli.app
class ApiConfig {
  static const String baseUrl =
      String.fromEnvironment('MWAVULI_API', defaultValue: 'http://129.205.2.218');
}
