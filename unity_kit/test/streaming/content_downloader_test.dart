import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:unity_kit/src/streaming/cache_manager.dart';
import 'package:unity_kit/src/streaming/content_downloader.dart';
import 'package:unity_kit/src/streaming/models/models.dart';

// ---------------------------------------------------------------------------
// Mock HTTP clients
// ---------------------------------------------------------------------------

/// A minimal mock HTTP client that returns configurable streamed responses.
class MockHttpClient extends http.BaseClient {
  MockHttpClient({
    this.responseBytes = const [],
    this.statusCode = 200,
    this.throwOnSend = false,
    this.chunkSize = 1024,
    this.delayPerChunk = Duration.zero,
  });

  final List<int> responseBytes;
  final int statusCode;
  final bool throwOnSend;
  final int chunkSize;
  final Duration delayPerChunk;

  int sendCallCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sendCallCount++;

    if (throwOnSend) {
      throw const SocketException('Simulated network failure');
    }

    final chunks = <List<int>>[];
    for (var i = 0; i < responseBytes.length; i += chunkSize) {
      final end = (i + chunkSize > responseBytes.length)
          ? responseBytes.length
          : i + chunkSize;
      chunks.add(responseBytes.sublist(i, end));
    }

    if (chunks.isEmpty) {
      chunks.add(<int>[]);
    }

    Stream<List<int>> byteStream;
    if (delayPerChunk > Duration.zero) {
      byteStream = _delayedStream(chunks, delayPerChunk);
    } else {
      byteStream = Stream.fromIterable(chunks);
    }

    return http.StreamedResponse(
      byteStream,
      statusCode,
      contentLength: responseBytes.length,
    );
  }

  Stream<List<int>> _delayedStream(
    List<List<int>> chunks,
    Duration delay,
  ) async* {
    for (final chunk in chunks) {
      await Future<void>.delayed(delay);
      yield chunk;
    }
  }
}

/// A mock HTTP client that fails a configurable number of times before
/// succeeding.
class FailThenSucceedHttpClient extends http.BaseClient {
  FailThenSucceedHttpClient({
    required this.failCount,
    required this.responseBytes,
  });

  final int failCount;
  final List<int> responseBytes;
  int sendCallCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sendCallCount++;

    if (sendCallCount <= failCount) {
      throw const SocketException('Simulated transient failure');
    }

    final stream = Stream.fromIterable([responseBytes]);
    return http.StreamedResponse(
      stream,
      200,
      contentLength: responseBytes.length,
    );
  }
}

/// A mock HTTP client whose stream can be externally controlled via a
/// [StreamController], allowing tests to cancel mid-download.
class ControllableHttpClient extends http.BaseClient {
  ControllableHttpClient({
    required this.chunkController,
    this.totalLength = 0,
  });

  final StreamController<List<int>> chunkController;
  final int totalLength;
  int sendCallCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sendCallCount++;
    return http.StreamedResponse(
      chunkController.stream,
      200,
      contentLength: totalLength,
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ContentDownloader', () {
    late Directory tempDir;
    late CacheManager cacheManager;

    const testBundle = ContentBundle(
      name: 'scene_main',
      url: 'https://cdn.example.com/scene_main.bin',
      sizeBytes: 1024,
    );

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('content_downloader_test_');
      cacheManager = CacheManager(cacheDirectory: tempDir);
      await cacheManager.initialize();
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    group('downloadBundle()', () {
      test('downloads bundle successfully with progress events', () async {
        final data = utf8.encode('Hello, bundle data!');
        final mockClient = MockHttpClient(
          responseBytes: data,
          chunkSize: 5,
        );
        final downloader = ContentDownloader(
          cacheManager: cacheManager,
          httpClient: mockClient,
        );

        final events = await downloader.downloadBundle(testBundle).toList();

        // starting event, then downloading chunks, then completed.
        expect(events.length, greaterThanOrEqualTo(3));
        expect(events.first.state, DownloadState.downloading);
        expect(events.last.state, DownloadState.completed);
        expect(events.last.isComplete, isTrue);

        downloader.dispose();
      });

      test('emits starting -> downloading -> completed sequence', () async {
        final data = utf8.encode('chunk_data');
        final mockClient = MockHttpClient(
          responseBytes: data,
          chunkSize: data.length,
        );
        final downloader = ContentDownloader(
          cacheManager: cacheManager,
          httpClient: mockClient,
        );

        final states = <DownloadState>[];
        await for (final progress in downloader.downloadBundle(testBundle)) {
          states.add(progress.state);
        }

        expect(states.first, DownloadState.downloading);
        expect(states.contains(DownloadState.downloading), isTrue);
        expect(states.last, DownloadState.completed);

        downloader.dispose();
      });

      test('returns cached for already-cached bundles', () async {
        await cacheManager.cacheBundle('scene_main', utf8.encode('cached'));

        final mockClient = MockHttpClient();
        final downloader = ContentDownloader(
          cacheManager: cacheManager,
          httpClient: mockClient,
        );

        final events = await downloader.downloadBundle(testBundle).toList();

        expect(events, hasLength(1));
        expect(events.first.state, DownloadState.cached);
        expect(mockClient.sendCallCount, 0);

        downloader.dispose();
      });

      test('retries on failure and eventually succeeds', () async {
        final data = utf8.encode('retry_success');
        final mockClient = FailThenSucceedHttpClient(
          failCount: 2,
          responseBytes: data,
        );
        final downloader = ContentDownloader(
          cacheManager: cacheManager,
          httpClient: mockClient,
          maxRetries: 3,
        );

        final events = await downloader.downloadBundle(testBundle).toList();
        final completedEvents =
            events.where((e) => e.state == DownloadState.completed);

        expect(completedEvents, hasLength(1));
        expect(mockClient.sendCallCount, 3);
        expect(cacheManager.isCached('scene_main'), isTrue);

        downloader.dispose();
      });

      test('emits failed after max retries exhausted', () async {
        final mockClient = MockHttpClient(throwOnSend: true);
        final downloader = ContentDownloader(
          cacheManager: cacheManager,
          httpClient: mockClient,
          maxRetries: 2,
        );

        final events = await downloader.downloadBundle(testBundle).toList();

        final failedEvents =
            events.where((e) => e.state == DownloadState.failed);
        expect(failedEvents, hasLength(1));
        expect(failedEvents.first.error, isNotNull);
        expect(mockClient.sendCallCount, 2);

        downloader.dispose();
      });

      test('emits failed on HTTP error status', () async {
        final mockClient = MockHttpClient(statusCode: 404);
        final downloader = ContentDownloader(
          cacheManager: cacheManager,
          httpClient: mockClient,
          maxRetries: 1,
        );

        final events = await downloader.downloadBundle(testBundle).toList();

        expect(events.last.state, DownloadState.failed);
        expect(events.last.error, contains('404'));

        downloader.dispose();
      });

      test('tracks download speed and ETA', () async {
        final data = List.filled(2048, 0x42);
        final mockClient = MockHttpClient(
          responseBytes: data,
          chunkSize: 512,
        );
        final downloader = ContentDownloader(
          cacheManager: cacheManager,
          httpClient: mockClient,
        );

        final downloadingEvents = <DownloadProgress>[];
        await for (final progress in downloader.downloadBundle(
          const ContentBundle(
            name: 'speed_test',
            url: 'https://cdn.example.com/speed_test.bin',
            sizeBytes: 2048,
          ),
        )) {
          if (progress.state == DownloadState.downloading) {
            downloadingEvents.add(progress);
          }
        }

        expect(downloadingEvents, isNotEmpty);
        for (final event in downloadingEvents) {
          expect(event.bytesPerSecond, greaterThanOrEqualTo(0));
        }

        downloader.dispose();
      });

      test('caches downloaded data with sha256 hash', () async {
        final data = utf8.encode('hash_verify');
        const bundle = ContentBundle(
          name: 'hashed_bundle',
          url: 'https://cdn.example.com/hashed.bin',
          sizeBytes: 11,
          sha256: 'provided_hash',
        );
        final mockClient = MockHttpClient(
          responseBytes: data,
          chunkSize: data.length,
        );
        final downloader = ContentDownloader(
          cacheManager: cacheManager,
          httpClient: mockClient,
        );

        await downloader.downloadBundle(bundle).toList();

        expect(cacheManager.isCached('hashed_bundle'), isTrue);
        final matches = await cacheManager.isCachedWithHash(
          'hashed_bundle',
          'provided_hash',
        );
        expect(matches, isTrue);

        downloader.dispose();
      });

      test('reports downloaded bytes matching actual data', () async {
        final data = utf8.encode('exact_bytes');
        final mockClient = MockHttpClient(
          responseBytes: data,
          chunkSize: 3,
        );
        final downloader = ContentDownloader(
          cacheManager: cacheManager,
          httpClient: mockClient,
        );

        final events = await downloader
            .downloadBundle(
              const ContentBundle(
                name: 'bytes_check',
                url: 'https://cdn.example.com/bytes_check.bin',
                sizeBytes: 11,
              ),
            )
            .toList();

        final downloadingEvents =
            events.where((e) => e.state == DownloadState.downloading).toList();
        expect(downloadingEvents.last.downloadedBytes, data.length);

        downloader.dispose();
      });
    });

    group('cancelDownload()', () {
      test('stops active download and emits cancelled', () async {
        // Use a controllable stream so we can cancel mid-download.
        final chunkController = StreamController<List<int>>();
        final mockClient = ControllableHttpClient(
          chunkController: chunkController,
          totalLength: 1024,
        );
        final downloader = ContentDownloader(
          cacheManager: cacheManager,
          httpClient: mockClient,
        );

        final events = <DownloadProgress>[];
        final done = Completer<void>();

        final subscription = downloader.downloadBundle(testBundle).listen(
          events.add,
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
        );

        // Feed some chunks, then cancel.
        chunkController.add(List.filled(256, 0x41));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        downloader.cancelDownload('scene_main');

        // Feed another chunk -- the cancellation check runs here.
        chunkController.add(List.filled(256, 0x42));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        await chunkController.close();
        await done.future;
        await subscription.cancel();

        final hasCancel = events.any((e) => e.state == DownloadState.cancelled);
        expect(hasCancel, isTrue);
        expect(cacheManager.isCached('scene_main'), isFalse);

        downloader.dispose();
      });
    });

    group('cancelAllDownloads()', () {
      test('clears all active downloads', () async {
        final chunkController = StreamController<List<int>>();
        final mockClient = ControllableHttpClient(
          chunkController: chunkController,
          totalLength: 1024,
        );
        final downloader = ContentDownloader(
          cacheManager: cacheManager,
          httpClient: mockClient,
        );

        final events = <DownloadProgress>[];
        final done = Completer<void>();

        final subscription = downloader.downloadBundle(testBundle).listen(
          events.add,
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
        );

        // Feed a chunk so the download is in progress.
        chunkController.add(List.filled(128, 0x41));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        downloader.cancelAllDownloads();
        expect(downloader.activeDownloadCount, 0);

        // Feed another chunk so the check triggers.
        chunkController.add(List.filled(128, 0x42));
        await chunkController.close();
        await done.future;
        await subscription.cancel();

        downloader.dispose();
      });
    });

    group('isDownloading()', () {
      test('returns true during active download', () async {
        final chunkController = StreamController<List<int>>();
        final mockClient = ControllableHttpClient(
          chunkController: chunkController,
          totalLength: 512,
        );
        final downloader = ContentDownloader(
          cacheManager: cacheManager,
          httpClient: mockClient,
        );

        final done = Completer<void>();
        downloader.downloadBundle(testBundle).listen(
          (_) {},
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
        );

        // Give the generator time to start executing.
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // While the stream is still open, the download is active.
        expect(downloader.isDownloading('scene_main'), isTrue);

        // Complete the stream.
        chunkController.add(List.filled(512, 0x41));
        await chunkController.close();
        await done.future;

        // After completion, download is cleaned up.
        expect(downloader.isDownloading('scene_main'), isFalse);

        downloader.dispose();
      });

      test('returns false for non-active bundle', () {
        final downloader = ContentDownloader(
          cacheManager: cacheManager,
          httpClient: MockHttpClient(),
        );

        expect(downloader.isDownloading('nonexistent'), isFalse);

        downloader.dispose();
      });
    });

    group('activeDownloadCount', () {
      test('starts at zero', () {
        final downloader = ContentDownloader(
          cacheManager: cacheManager,
          httpClient: MockHttpClient(),
        );

        expect(downloader.activeDownloadCount, 0);

        downloader.dispose();
      });

      test('tracks active downloads', () async {
        final chunkController = StreamController<List<int>>();
        final mockClient = ControllableHttpClient(
          chunkController: chunkController,
          totalLength: 256,
        );
        final downloader = ContentDownloader(
          cacheManager: cacheManager,
          httpClient: mockClient,
        );

        final done = Completer<void>();
        downloader.downloadBundle(testBundle).listen(
          (_) {},
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(downloader.activeDownloadCount, 1);

        chunkController.add(List.filled(256, 0x41));
        await chunkController.close();
        await done.future;

        expect(downloader.activeDownloadCount, 0);

        downloader.dispose();
      });
    });

    group('dispose()', () {
      test('prevents new downloads', () async {
        final downloader = ContentDownloader(
          cacheManager: cacheManager,
          httpClient: MockHttpClient(responseBytes: utf8.encode('data')),
        );

        downloader.dispose();

        final events = await downloader.downloadBundle(testBundle).toList();
        expect(events, isEmpty);
      });

      test('clears active downloads', () async {
        final chunkController = StreamController<List<int>>();
        final mockClient = ControllableHttpClient(
          chunkController: chunkController,
          totalLength: 1024,
        );
        final downloader = ContentDownloader(
          cacheManager: cacheManager,
          httpClient: mockClient,
        );

        final done = Completer<void>();
        downloader.downloadBundle(testBundle).listen(
          (_) {},
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(downloader.activeDownloadCount, 1);

        downloader.dispose();
        expect(downloader.activeDownloadCount, 0);

        // Complete the controller so the stream finishes.
        chunkController.add(List.filled(64, 0x41));
        await chunkController.close();
        await done.future;
      });
    });

    group('downloadBundles()', () {
      test('downloads all bundles sequentially', () async {
        final data = utf8.encode('batch_data');
        final mockClient = MockHttpClient(
          responseBytes: data,
          chunkSize: data.length,
        );
        final downloader = ContentDownloader(
          cacheManager: cacheManager,
          httpClient: mockClient,
        );

        const bundles = [
          ContentBundle(
            name: 'batch_a',
            url: 'https://cdn.example.com/a.bin',
            sizeBytes: 10,
          ),
          ContentBundle(
            name: 'batch_b',
            url: 'https://cdn.example.com/b.bin',
            sizeBytes: 10,
          ),
        ];

        final events = await downloader
            .downloadBundles(bundles, DownloadStrategy.any)
            .toList();

        final completedNames = events
            .where((e) => e.state == DownloadState.completed)
            .map((e) => e.bundleName)
            .toList();

        expect(completedNames, containsAll(['batch_a', 'batch_b']));
        expect(cacheManager.isCached('batch_a'), isTrue);
        expect(cacheManager.isCached('batch_b'), isTrue);

        downloader.dispose();
      });

      test('skips when strategy is manual', () async {
        final downloader = ContentDownloader(
          cacheManager: cacheManager,
          httpClient: MockHttpClient(responseBytes: utf8.encode('data')),
        );

        final events = await downloader
            .downloadBundles([testBundle], DownloadStrategy.manual).toList();

        expect(events, isEmpty);

        downloader.dispose();
      });

      test('returns empty when disposed', () async {
        final downloader = ContentDownloader(
          cacheManager: cacheManager,
          httpClient: MockHttpClient(responseBytes: utf8.encode('data')),
        );
        downloader.dispose();

        final events = await downloader
            .downloadBundles([testBundle], DownloadStrategy.any).toList();

        expect(events, isEmpty);
      });
    });

    group('HttpDownloadException', () {
      test('has correct message and statusCode', () {
        const exception = HttpDownloadException(
          'Not found',
          statusCode: 404,
        );

        expect(exception.message, 'Not found');
        expect(exception.statusCode, 404);
        expect(exception.toString(), 'HttpDownloadException: Not found');
      });

      test('statusCode is null when not provided', () {
        const exception = HttpDownloadException('Generic error');

        expect(exception.statusCode, isNull);
      });
    });
  });
}
