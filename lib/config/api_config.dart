import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._();

  /// Sobrescreva em build: flutter run --dart-define=API_BASE_URL=https://api.exemplo.com
  static const String _fromEnvironment = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_fromEnvironment.isNotEmpty) return _fromEnvironment;
    // O emulador Android enxerga o localhost da máquina host como 10.0.2.2.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const int pageSize = 20;
}
