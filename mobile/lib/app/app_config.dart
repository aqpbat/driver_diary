/// Build-time settings, passed with `--dart-define`.
final class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.driverOffset});

  /// Reads `API_BASE_URL` and `DRIVER_UTC_OFFSET`.
  factory AppConfig.fromEnvironment() => AppConfig(
    apiBaseUrl: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8080',
    ),
    driverOffset: parseUtcOffset(
      const String.fromEnvironment('DRIVER_UTC_OFFSET', defaultValue: '+05:00'),
    ),
  );

  final String apiBaseUrl;

  /// The driver's zone as a fixed offset from UTC. It must match the
  /// server's `APP_TZ` (`Asia/Almaty`, UTC+5, no daylight saving): times typed
  /// into the form are sent with this offset, and "today" is counted on this
  /// clock rather than the device's.
  final Duration driverOffset;
}

/// Parses `+05:00` / `-03:30`. Throws [FormatException] on anything else.
Duration parseUtcOffset(String text) {
  final match = RegExp(r'^([+-])(\d{2}):(\d{2})$').firstMatch(text);
  if (match == null) {
    throw FormatException('Offset must look like +05:00', text);
  }
  final offset = Duration(
    hours: int.parse(match[2]!),
    minutes: int.parse(match[3]!),
  );
  return match[1] == '-' ? -offset : offset;
}
