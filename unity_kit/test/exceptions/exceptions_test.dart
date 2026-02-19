import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/exceptions/exceptions.dart';
import 'package:unity_kit/src/models/unity_lifecycle_state.dart';

void main() {
  group('UnityKitException', () {
    test('stores message', () {
      const exception = UnityKitException(message: 'something went wrong');

      expect(exception.message, 'something went wrong');
      expect(exception.cause, isNull);
      expect(exception.stackTrace, isNull);
    });

    test('stores cause and stackTrace', () {
      final cause = Exception('root cause');
      final trace = StackTrace.current;
      final exception = UnityKitException(
        message: 'wrapped error',
        cause: cause,
        stackTrace: trace,
      );

      expect(exception.cause, cause);
      expect(exception.stackTrace, trace);
    });

    test('toString without cause', () {
      const exception = UnityKitException(message: 'simple error');

      expect(exception.toString(), 'UnityKitException: simple error');
    });

    test('toString with cause', () {
      final cause = Exception('root');
      final exception = UnityKitException(
        message: 'wrapped',
        cause: cause,
      );

      expect(
        exception.toString(),
        contains('UnityKitException: wrapped'),
      );
      expect(exception.toString(), contains('Caused by:'));
    });

    test('implements Exception', () {
      const exception = UnityKitException(message: 'test');

      expect(exception, isA<Exception>());
    });
  });

  group('BridgeException', () {
    test('extends UnityKitException', () {
      const exception = BridgeException(message: 'bridge failed');

      expect(exception, isA<UnityKitException>());
      expect(exception, isA<Exception>());
    });

    test('stores message', () {
      const exception = BridgeException(message: 'bridge failed');

      expect(exception.message, 'bridge failed');
    });

    test('stores cause and stackTrace', () {
      final cause = Exception('underlying');
      final trace = StackTrace.current;
      final exception = BridgeException(
        message: 'bridge error',
        cause: cause,
        stackTrace: trace,
      );

      expect(exception.cause, cause);
      expect(exception.stackTrace, trace);
    });

    test('toString', () {
      const exception = BridgeException(message: 'connection lost');

      expect(exception.toString(), 'BridgeException: connection lost');
    });
  });

  group('LifecycleException', () {
    test('extends UnityKitException', () {
      final exception = LifecycleException(
        currentState: UnityLifecycleState.disposed,
        attemptedAction: 'sendMessage',
      );

      expect(exception, isA<UnityKitException>());
      expect(exception, isA<Exception>());
    });

    test('constructs message from state and action', () {
      final exception = LifecycleException(
        currentState: UnityLifecycleState.disposed,
        attemptedAction: 'sendMessage',
      );

      expect(
        exception.message,
        'Invalid lifecycle action "sendMessage" in state '
        'UnityLifecycleState.disposed',
      );
    });

    test('stores currentState and attemptedAction', () {
      final exception = LifecycleException(
        currentState: UnityLifecycleState.uninitialized,
        attemptedAction: 'pause',
      );

      expect(exception.currentState, UnityLifecycleState.uninitialized);
      expect(exception.attemptedAction, 'pause');
    });

    test('toString', () {
      final exception = LifecycleException(
        currentState: UnityLifecycleState.paused,
        attemptedAction: 'initialize',
      );

      expect(
        exception.toString(),
        'LifecycleException: Cannot initialize in state '
        'UnityLifecycleState.paused',
      );
    });

    test('stores cause and stackTrace', () {
      final cause = Exception('inner');
      final trace = StackTrace.current;
      final exception = LifecycleException(
        currentState: UnityLifecycleState.ready,
        attemptedAction: 'init',
        cause: cause,
        stackTrace: trace,
      );

      expect(exception.cause, cause);
      expect(exception.stackTrace, trace);
    });
  });

  group('CommunicationException', () {
    test('extends UnityKitException', () {
      const exception = CommunicationException(message: 'delivery failed');

      expect(exception, isA<UnityKitException>());
      expect(exception, isA<Exception>());
    });

    test('stores all fields', () {
      const exception = CommunicationException(
        message: 'timeout',
        target: 'GameManager',
        method: 'LoadScene',
        data: '{"scene": "main"}',
      );

      expect(exception.message, 'timeout');
      expect(exception.target, 'GameManager');
      expect(exception.method, 'LoadScene');
      expect(exception.data, '{"scene": "main"}');
    });

    test('toString without target or method', () {
      const exception = CommunicationException(message: 'failed');

      expect(exception.toString(), 'CommunicationException: failed');
    });

    test('toString with target', () {
      const exception = CommunicationException(
        message: 'not found',
        target: 'Player',
      );

      expect(
        exception.toString(),
        'CommunicationException: not found (target: Player)',
      );
    });

    test('toString with target and method', () {
      const exception = CommunicationException(
        message: 'error',
        target: 'GameManager',
        method: 'LoadScene',
      );

      expect(
        exception.toString(),
        'CommunicationException: error '
        '(target: GameManager) (method: LoadScene)',
      );
    });

    test('toString with method only', () {
      const exception = CommunicationException(
        message: 'error',
        method: 'LoadScene',
      );

      expect(
        exception.toString(),
        'CommunicationException: error (method: LoadScene)',
      );
    });

    test('optional fields default to null', () {
      const exception = CommunicationException(message: 'test');

      expect(exception.target, isNull);
      expect(exception.method, isNull);
      expect(exception.data, isNull);
      expect(exception.cause, isNull);
      expect(exception.stackTrace, isNull);
    });
  });

  group('EngineNotReadyException', () {
    test('extends UnityKitException', () {
      const exception = EngineNotReadyException();

      expect(exception, isA<UnityKitException>());
      expect(exception, isA<Exception>());
    });

    test('has default message', () {
      const exception = EngineNotReadyException();

      expect(
        exception.message,
        'Unity engine is not ready. Call initialize() first or use '
        'sendWhenReady().',
      );
    });

    test('toString', () {
      const exception = EngineNotReadyException();

      expect(
        exception.toString(),
        'EngineNotReadyException: Unity engine is not ready. '
        'Call initialize() first or use sendWhenReady().',
      );
    });

    test('stores cause and stackTrace', () {
      final cause = Exception('not initialized');
      final trace = StackTrace.current;
      final exception = EngineNotReadyException(
        cause: cause,
        stackTrace: trace,
      );

      expect(exception.cause, cause);
      expect(exception.stackTrace, trace);
    });
  });
}
