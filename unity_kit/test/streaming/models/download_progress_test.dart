import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/streaming/models/download_progress.dart';
import 'package:unity_kit/src/streaming/models/download_state.dart';

void main() {
  group('DownloadProgress', () {
    group('starting factory', () {
      test('creates progress at zero', () {
        final progress = DownloadProgress.starting('core', 1024);

        expect(progress.bundleName, 'core');
        expect(progress.downloadedBytes, 0);
        expect(progress.totalBytes, 1024);
        expect(progress.state, DownloadState.downloading);
        expect(progress.error, isNull);
      });
    });

    group('completed factory', () {
      test('creates fully downloaded progress', () {
        final progress = DownloadProgress.completed('core', 1024);

        expect(progress.downloadedBytes, 1024);
        expect(progress.totalBytes, 1024);
        expect(progress.state, DownloadState.completed);
        expect(progress.isComplete, true);
      });
    });

    group('cached factory', () {
      test('creates cached progress', () {
        final progress = DownloadProgress.cached('core', 1024);

        expect(progress.downloadedBytes, 1024);
        expect(progress.totalBytes, 1024);
        expect(progress.state, DownloadState.cached);
      });
    });

    group('failed factory', () {
      test('creates failed progress without error', () {
        final progress = DownloadProgress.failed('core');

        expect(progress.state, DownloadState.failed);
        expect(progress.error, isNull);
        expect(progress.isFailed, true);
      });

      test('creates failed progress with error', () {
        final progress = DownloadProgress.failed(
          'core',
          error: 'Connection timeout',
        );

        expect(progress.error, 'Connection timeout');
        expect(progress.isFailed, true);
      });
    });

    group('percentage', () {
      test('returns 0.0 when no bytes downloaded', () {
        final progress = DownloadProgress.starting('core', 1024);

        expect(progress.percentage, 0.0);
      });

      test('returns 1.0 when fully downloaded', () {
        final progress = DownloadProgress.completed('core', 1024);

        expect(progress.percentage, 1.0);
      });

      test('returns correct fraction', () {
        const progress = DownloadProgress(
          bundleName: 'core',
          downloadedBytes: 750,
          totalBytes: 1000,
          state: DownloadState.downloading,
        );

        expect(progress.percentage, 0.75);
      });

      test('returns 0.0 when totalBytes is zero', () {
        const progress = DownloadProgress(
          bundleName: 'core',
          downloadedBytes: 0,
          totalBytes: 0,
          state: DownloadState.failed,
        );

        expect(progress.percentage, 0.0);
      });

      test('clamps to 1.0 when downloadedBytes exceeds totalBytes', () {
        const progress = DownloadProgress(
          bundleName: 'core',
          downloadedBytes: 2000,
          totalBytes: 1000,
          state: DownloadState.downloading,
        );

        expect(progress.percentage, 1.0);
      });
    });

    group('percentageString', () {
      test('formats zero percent', () {
        final progress = DownloadProgress.starting('core', 1024);

        expect(progress.percentageString, '0%');
      });

      test('formats 100 percent', () {
        final progress = DownloadProgress.completed('core', 1024);

        expect(progress.percentageString, '100%');
      });

      test('rounds to nearest integer', () {
        const progress = DownloadProgress(
          bundleName: 'core',
          downloadedBytes: 333,
          totalBytes: 1000,
          state: DownloadState.downloading,
        );

        expect(progress.percentageString, '33%');
      });
    });

    group('state checks', () {
      test('isComplete is true only for completed state', () {
        final completed = DownloadProgress.completed('core', 1024);
        final downloading = DownloadProgress.starting('core', 1024);

        expect(completed.isComplete, true);
        expect(downloading.isComplete, false);
      });

      test('isFailed is true only for failed state', () {
        final failed = DownloadProgress.failed('core');
        final completed = DownloadProgress.completed('core', 1024);

        expect(failed.isFailed, true);
        expect(completed.isFailed, false);
      });

      test('isInProgress is true only for downloading state', () {
        final downloading = DownloadProgress.starting('core', 1024);
        final completed = DownloadProgress.completed('core', 1024);

        expect(downloading.isInProgress, true);
        expect(completed.isInProgress, false);
      });
    });

    group('speedString', () {
      test('formats bytes per second', () {
        const progress = DownloadProgress(
          bundleName: 'core',
          downloadedBytes: 100,
          totalBytes: 1024,
          state: DownloadState.downloading,
          bytesPerSecond: 512,
        );

        expect(progress.speedString, '512 B/s');
      });

      test('formats kilobytes per second', () {
        const progress = DownloadProgress(
          bundleName: 'core',
          downloadedBytes: 100,
          totalBytes: 1024,
          state: DownloadState.downloading,
          bytesPerSecond: 150 * 1024,
        );

        expect(progress.speedString, '150.0 KB/s');
      });

      test('formats megabytes per second', () {
        const progress = DownloadProgress(
          bundleName: 'core',
          downloadedBytes: 100,
          totalBytes: 1024 * 1024,
          state: DownloadState.downloading,
          bytesPerSecond: 2621440, // 2.5 MB
        );

        expect(progress.speedString, '2.5 MB/s');
      });
    });

    group('etaString', () {
      test('formats zero seconds', () {
        const progress = DownloadProgress(
          bundleName: 'core',
          downloadedBytes: 1024,
          totalBytes: 1024,
          state: DownloadState.completed,
        );

        expect(progress.etaString, '0s');
      });

      test('formats seconds only', () {
        const progress = DownloadProgress(
          bundleName: 'core',
          downloadedBytes: 500,
          totalBytes: 1024,
          state: DownloadState.downloading,
          estimatedSecondsRemaining: 45,
        );

        expect(progress.etaString, '45s');
      });

      test('formats minutes and seconds', () {
        const progress = DownloadProgress(
          bundleName: 'core',
          downloadedBytes: 500,
          totalBytes: 1024,
          state: DownloadState.downloading,
          estimatedSecondsRemaining: 150,
        );

        expect(progress.etaString, '2m 30s');
      });
    });

    test('toString returns readable format', () {
      final progress = DownloadProgress.starting('core', 1024);

      expect(progress.toString(), contains('DownloadProgress'));
      expect(progress.toString(), contains('core'));
      expect(progress.toString(), contains('0%'));
    });
  });
}
