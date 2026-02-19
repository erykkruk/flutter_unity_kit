import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/utils/logger.dart';

/// Test logger that captures log calls.
class TestLogger implements UnityKitLogger {
  final List<String> logs = [];
  bool _isDebugEnabled = true;

  @override
  bool get isDebugEnabled => _isDebugEnabled;

  @override
  set isDebugEnabled(bool value) => _isDebugEnabled = value;

  @override
  void debug(String message) {
    if (!_isDebugEnabled) return;
    logs.add('DEBUG: $message');
  }

  @override
  void info(String message) => logs.add('INFO: $message');

  @override
  void warning(String message) => logs.add('WARNING: $message');

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    logs.add('ERROR: $message');
  }
}

void main() {
  group('LogLevel', () {
    test('has all expected values', () {
      expect(LogLevel.values, hasLength(4));
      expect(
        LogLevel.values,
        containsAll([
          LogLevel.debug,
          LogLevel.info,
          LogLevel.warning,
          LogLevel.error,
        ]),
      );
    });

    test('enum values have correct names', () {
      expect(LogLevel.debug.name, 'debug');
      expect(LogLevel.info.name, 'info');
      expect(LogLevel.warning.name, 'warning');
      expect(LogLevel.error.name, 'error');
    });

    test('enum values have correct indices (severity order)', () {
      expect(LogLevel.debug.index, 0);
      expect(LogLevel.info.index, 1);
      expect(LogLevel.warning.index, 2);
      expect(LogLevel.error.index, 3);
    });

    test('severity increases with index', () {
      expect(LogLevel.debug.index, lessThan(LogLevel.info.index));
      expect(LogLevel.info.index, lessThan(LogLevel.warning.index));
      expect(LogLevel.warning.index, lessThan(LogLevel.error.index));
    });
  });

  group('UnityKitLogger', () {
    late TestLogger testLogger;

    setUp(() {
      testLogger = TestLogger();
      UnityKitLogger.instance = testLogger;
    });

    tearDown(() {
      UnityKitLogger.instance = DefaultUnityKitLogger();
    });

    test('singleton instance can be replaced', () {
      expect(UnityKitLogger.instance, same(testLogger));
    });

    test('debug logs when enabled', () {
      testLogger.isDebugEnabled = true;
      UnityKitLogger.instance.debug('test message');
      expect(testLogger.logs, contains('DEBUG: test message'));
    });

    test('debug does not log when disabled', () {
      testLogger.isDebugEnabled = false;
      UnityKitLogger.instance.debug('test message');
      expect(testLogger.logs, isEmpty);
    });

    test('info logs message', () {
      UnityKitLogger.instance.info('info message');
      expect(testLogger.logs, contains('INFO: info message'));
    });

    test('warning logs message', () {
      UnityKitLogger.instance.warning('warning message');
      expect(testLogger.logs, contains('WARNING: warning message'));
    });

    test('error logs message', () {
      UnityKitLogger.instance.error('error message');
      expect(testLogger.logs, contains('ERROR: error message'));
    });

    test('error logs with exception', () {
      final exception = Exception('test');
      UnityKitLogger.instance.error('error message', exception);
      expect(testLogger.logs, contains('ERROR: error message'));
    });
  });

  group('DefaultUnityKitLogger', () {
    test('debug is disabled by default', () {
      final logger = DefaultUnityKitLogger();
      expect(logger.isDebugEnabled, isFalse);
    });

    test('debug can be enabled', () {
      final logger = DefaultUnityKitLogger();
      logger.isDebugEnabled = true;
      expect(logger.isDebugEnabled, isTrue);
    });

    test('all methods can be called without error', () {
      final logger = DefaultUnityKitLogger();
      logger.isDebugEnabled = true;

      expect(() => logger.debug('debug'), returnsNormally);
      expect(() => logger.info('info'), returnsNormally);
      expect(() => logger.warning('warning'), returnsNormally);
      expect(() => logger.error('error'), returnsNormally);
      expect(
        () => logger.error('error', Exception('test'), StackTrace.current),
        returnsNormally,
      );
    });
  });
}
