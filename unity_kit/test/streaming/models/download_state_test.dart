import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/streaming/models/download_state.dart';

void main() {
  group('DownloadState', () {
    test('has all expected values', () {
      expect(DownloadState.values, hasLength(6));
      expect(
        DownloadState.values,
        containsAll([
          DownloadState.queued,
          DownloadState.downloading,
          DownloadState.completed,
          DownloadState.cached,
          DownloadState.failed,
          DownloadState.cancelled,
        ]),
      );
    });

    test('enum values have correct names', () {
      expect(DownloadState.queued.name, 'queued');
      expect(DownloadState.downloading.name, 'downloading');
      expect(DownloadState.completed.name, 'completed');
      expect(DownloadState.cached.name, 'cached');
      expect(DownloadState.failed.name, 'failed');
      expect(DownloadState.cancelled.name, 'cancelled');
    });

    test('enum values have correct indices', () {
      expect(DownloadState.queued.index, 0);
      expect(DownloadState.downloading.index, 1);
      expect(DownloadState.completed.index, 2);
      expect(DownloadState.cached.index, 3);
      expect(DownloadState.failed.index, 4);
      expect(DownloadState.cancelled.index, 5);
    });
  });
}
