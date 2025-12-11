// lib/data/backend_config.dart
//
// Central place to configure the Python analytics backend.
// Change the default URL for production (e.g. to your deployed FastAPI host).

class BackendConfig {
  BackendConfig._();

  /// Base URL of the Python backend (FastAPI).
  /// You can override this at build time:
  ///   flutter run --dart-define=BACKEND_BASE_URL=https://your-host
  static const String baseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  /// Helper to build a Uri for a backend path, e.g.
  ///   BackendConfig.uri('/api/v1/analytics/medicine-names')
  static Uri uri(String path, [Map<String, String>? query]) {
    final normalizedBase =
        baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;
    final String full = '$normalizedBase$path';
    final uri = Uri.parse(full);
    return query == null ? uri : uri.replace(queryParameters: query);
  }
}
