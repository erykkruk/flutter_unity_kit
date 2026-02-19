import 'dart:developer' as developer;

/// Log severity levels.
enum LogLevel {
  /// Debug messages for development.
  debug,

  /// Informational messages.
  info,

  /// Warning messages for potential issues.
  warning,

  /// Error messages for failures.
  error,
}

/// Abstract logger interface for unity_kit.
///
/// Allows swapping the logger implementation (e.g., for testing).
///
/// Example:
/// ```dart
/// // Use default logger
/// UnityKitLogger.instance.info('Unity initialized');
///
/// // Replace with custom logger
/// UnityKitLogger.instance = MyCustomLogger();
/// ```
abstract class UnityKitLogger {
  /// Singleton instance. Can be replaced for testing or custom logging.
  static UnityKitLogger instance = DefaultUnityKitLogger();

  /// Whether debug logging is enabled.
  bool get isDebugEnabled;

  /// Enable or disable debug logging.
  set isDebugEnabled(bool value);

  /// Log a debug message.
  void debug(String message);

  /// Log an informational message.
  void info(String message);

  /// Log a warning message.
  void warning(String message);

  /// Log an error with optional exception and stack trace.
  void error(String message, [Object? error, StackTrace? stackTrace]);
}

/// Default logger implementation using `dart:developer`.
class DefaultUnityKitLogger implements UnityKitLogger {
  static const String _prefix = '[UnityKit]';

  bool _isDebugEnabled = false;

  @override
  bool get isDebugEnabled => _isDebugEnabled;

  @override
  set isDebugEnabled(bool value) => _isDebugEnabled = value;

  @override
  void debug(String message) {
    if (!_isDebugEnabled) return;
    developer.log('$_prefix $message', level: 500, name: 'unity_kit');
  }

  @override
  void info(String message) {
    developer.log('$_prefix $message', level: 800, name: 'unity_kit');
  }

  @override
  void warning(String message) {
    developer.log('$_prefix WARNING: $message', level: 900, name: 'unity_kit');
  }

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      '$_prefix ERROR: $message',
      level: 1000,
      name: 'unity_kit',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
