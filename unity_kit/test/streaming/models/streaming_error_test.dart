import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/streaming/models/streaming_error.dart';

void main() {
  group('StreamingErrorType', () {
    test('has all expected values', () {
      expect(StreamingErrorType.values, hasLength(7));
      expect(
        StreamingErrorType.values,
        containsAll([
          StreamingErrorType.notInitialized,
          StreamingErrorType.initializationFailed,
          StreamingErrorType.manifestFetchFailed,
          StreamingErrorType.bundleNotFound,
          StreamingErrorType.downloadFailed,
          StreamingErrorType.networkUnavailable,
          StreamingErrorType.cacheError,
        ]),
      );
    });

    test('enum values have correct names', () {
      expect(StreamingErrorType.notInitialized.name, 'notInitialized');
      expect(
        StreamingErrorType.initializationFailed.name,
        'initializationFailed',
      );
      expect(
        StreamingErrorType.manifestFetchFailed.name,
        'manifestFetchFailed',
      );
      expect(StreamingErrorType.bundleNotFound.name, 'bundleNotFound');
      expect(StreamingErrorType.downloadFailed.name, 'downloadFailed');
      expect(
        StreamingErrorType.networkUnavailable.name,
        'networkUnavailable',
      );
      expect(StreamingErrorType.cacheError.name, 'cacheError');
    });
  });

  group('StreamingError', () {
    group('constructor', () {
      test('creates instance with required parameters', () {
        const error = StreamingError(
          type: StreamingErrorType.downloadFailed,
          message: 'Connection timed out',
        );

        expect(error.type, StreamingErrorType.downloadFailed);
        expect(error.message, 'Connection timed out');
        expect(error.cause, isNull);
      });

      test('creates instance with all parameters', () {
        final cause = Exception('network error');
        final error = StreamingError(
          type: StreamingErrorType.networkUnavailable,
          message: 'No internet',
          cause: cause,
        );

        expect(error.type, StreamingErrorType.networkUnavailable);
        expect(error.message, 'No internet');
        expect(error.cause, cause);
      });
    });

    group('toString', () {
      test('returns formatted string', () {
        const error = StreamingError(
          type: StreamingErrorType.bundleNotFound,
          message: 'Bundle "chars" not found',
        );

        expect(
          error.toString(),
          'StreamingError(StreamingErrorType.bundleNotFound): '
          'Bundle "chars" not found',
        );
      });
    });

    group('equality', () {
      test('equal when type and message match', () {
        const error1 = StreamingError(
          type: StreamingErrorType.downloadFailed,
          message: 'timeout',
        );
        const error2 = StreamingError(
          type: StreamingErrorType.downloadFailed,
          message: 'timeout',
        );

        expect(error1, equals(error2));
        expect(error1.hashCode, equals(error2.hashCode));
      });

      test('equal even when cause differs', () {
        final error1 = StreamingError(
          type: StreamingErrorType.downloadFailed,
          message: 'timeout',
          cause: Exception('a'),
        );
        final error2 = StreamingError(
          type: StreamingErrorType.downloadFailed,
          message: 'timeout',
          cause: Exception('b'),
        );

        expect(error1, equals(error2));
      });

      test('not equal when type differs', () {
        const error1 = StreamingError(
          type: StreamingErrorType.downloadFailed,
          message: 'timeout',
        );
        const error2 = StreamingError(
          type: StreamingErrorType.cacheError,
          message: 'timeout',
        );

        expect(error1, isNot(equals(error2)));
      });

      test('not equal when message differs', () {
        const error1 = StreamingError(
          type: StreamingErrorType.downloadFailed,
          message: 'timeout',
        );
        const error2 = StreamingError(
          type: StreamingErrorType.downloadFailed,
          message: 'connection refused',
        );

        expect(error1, isNot(equals(error2)));
      });

      test('identical instances are equal', () {
        const error = StreamingError(
          type: StreamingErrorType.downloadFailed,
          message: 'timeout',
        );

        expect(error, equals(error));
      });

      test('not equal to different type', () {
        const error = StreamingError(
          type: StreamingErrorType.downloadFailed,
          message: 'timeout',
        );
        const Object other = 'not an error';

        // ignore: unrelated_type_equality_checks
        expect(error == other, isFalse);
      });
    });

    group('hashCode', () {
      test('same for equal instances', () {
        const error1 = StreamingError(
          type: StreamingErrorType.cacheError,
          message: 'disk full',
        );
        const error2 = StreamingError(
          type: StreamingErrorType.cacheError,
          message: 'disk full',
        );

        expect(error1.hashCode, equals(error2.hashCode));
      });

      test('different for different instances', () {
        const error1 = StreamingError(
          type: StreamingErrorType.cacheError,
          message: 'disk full',
        );
        const error2 = StreamingError(
          type: StreamingErrorType.downloadFailed,
          message: 'network',
        );

        expect(error1.hashCode, isNot(equals(error2.hashCode)));
      });
    });
  });
}
