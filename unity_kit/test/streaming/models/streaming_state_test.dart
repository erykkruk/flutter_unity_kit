import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/streaming/models/streaming_state.dart';

void main() {
  group('StreamingState', () {
    test('has all expected values', () {
      expect(StreamingState.values, hasLength(5));
      expect(
        StreamingState.values,
        containsAll([
          StreamingState.uninitialized,
          StreamingState.initializing,
          StreamingState.ready,
          StreamingState.downloading,
          StreamingState.error,
        ]),
      );
    });

    test('enum values have correct names', () {
      expect(StreamingState.uninitialized.name, 'uninitialized');
      expect(StreamingState.initializing.name, 'initializing');
      expect(StreamingState.ready.name, 'ready');
      expect(StreamingState.downloading.name, 'downloading');
      expect(StreamingState.error.name, 'error');
    });

    test('enum values have correct indices', () {
      expect(StreamingState.uninitialized.index, 0);
      expect(StreamingState.initializing.index, 1);
      expect(StreamingState.ready.index, 2);
      expect(StreamingState.downloading.index, 3);
      expect(StreamingState.error.index, 4);
    });
  });
}
