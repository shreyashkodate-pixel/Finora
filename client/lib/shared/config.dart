/// Application runtime configuration.
/// Values are environment-driven via compile-time --dart-define parameters
/// with safe local development defaults per SRS §3.3.
class AppConfig {
  /// Base API URL for FastAPI backend (/api/v1)
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api/v1',
  );

  /// Application Name
  static const String appName = 'AI IT Helpdesk';

  /// Default HTTP timeout in milliseconds
  static const int requestTimeoutMs = int.fromEnvironment(
    'REQUEST_TIMEOUT_MS',
    defaultValue: 15000,
  );

  /// Maximum file upload size in MB per SRS §7.5
  static const int maxFileUploadMb = 10;

  /// Maximum case attachments quota in MB per SRS §7.5
  static const int maxCaseQuotaMb = 50;
}
