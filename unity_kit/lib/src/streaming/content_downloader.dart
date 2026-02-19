import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../utils/logger.dart';
import 'cache_manager.dart';
import 'models/models.dart';

/// Downloads content bundles from HTTP with progress tracking.
///
/// Supports single and batch downloads with configurable concurrency,
/// automatic retries with exponential backoff, and cancellation.
///
/// Example:
/// ```dart
/// final downloader = ContentDownloader(cacheManager: cache);
///
/// await for (final progress in downloader.downloadBundle(bundle)) {
///   debugPrint('${progress.percentageString} - ${progress.speedString}');
/// }
/// ```
class ContentDownloader {
  /// Creates a [ContentDownloader].
  ///
  /// [cacheManager] must be initialized before downloading.
  /// [httpClient] allows injecting a custom client for testing.
  /// [maxRetries] controls how many times a failed download is retried.
  /// [maxConcurrency] limits parallel downloads in [downloadBundles].
  ContentDownloader({
    required this.cacheManager,
    http.Client? httpClient,
    this.maxRetries = 3,
    this.maxConcurrency = 3,
  }) : _httpClient = httpClient ?? http.Client();

  /// The cache manager used to store downloaded bundles.
  final CacheManager cacheManager;

  final http.Client _httpClient;

  /// Maximum number of retry attempts for a failed download.
  final int maxRetries;

  /// Maximum number of concurrent downloads in [downloadBundles].
  final int maxConcurrency;

  final Map<String, _ActiveDownload> _activeDownloads = {};
  bool _isDisposed = false;

  /// Download a single bundle with progress tracking.
  ///
  /// Emits [DownloadProgress] events as data arrives. If the bundle
  /// is already cached, a single [DownloadState.cached] event is emitted.
  ///
  /// Retries up to [maxRetries] times on failure with exponential backoff.
  Stream<DownloadProgress> downloadBundle(ContentBundle bundle) async* {
    if (_isDisposed) return;

    if (cacheManager.isCached(bundle.name)) {
      UnityKitLogger.instance.debug(
        'Bundle "${bundle.name}" already cached, skipping download',
      );
      yield DownloadProgress.cached(bundle.name, bundle.sizeBytes);
      return;
    }

    yield DownloadProgress.starting(bundle.name, bundle.sizeBytes);

    final completer = Completer<void>();
    final controller = StreamController<DownloadProgress>.broadcast();
    _activeDownloads[bundle.name] = _ActiveDownload(
      completer: completer,
      controller: controller,
    );

    var attempt = 0;
    var succeeded = false;

    while (attempt < maxRetries && !succeeded) {
      attempt++;
      try {
        final result = await _executeDownload(bundle, controller);

        // Yield all collected progress events.
        for (final progress in result.progressEvents) {
          yield progress;
        }

        if (result.cancelled) {
          yield DownloadProgress(
            bundleName: bundle.name,
            downloadedBytes: 0,
            totalBytes: bundle.sizeBytes,
            state: DownloadState.cancelled,
          );
          break;
        }

        // Cache the downloaded data.
        await cacheManager.cacheBundle(
          bundle.name,
          result.bytes,
          sha256Hash: bundle.sha256,
        );

        UnityKitLogger.instance.info(
          'Downloaded "${bundle.name}" (${result.bytes.length} bytes)',
        );
        yield DownloadProgress.completed(bundle.name, result.totalBytes);
        succeeded = true;
      } catch (e, stackTrace) {
        UnityKitLogger.instance.error(
          'Download attempt $attempt/$maxRetries failed for "${bundle.name}"',
          e,
          stackTrace,
        );

        if (attempt >= maxRetries) {
          yield DownloadProgress.failed(
            bundle.name,
            error: e.toString(),
          );
        } else {
          final backoffSeconds = attempt * 2;
          UnityKitLogger.instance.debug(
            'Retrying "${bundle.name}" in ${backoffSeconds}s',
          );
          await Future<void>.delayed(Duration(seconds: backoffSeconds));
        }
      }
    }

    _cleanupDownload(bundle.name);
  }

  /// Execute the HTTP download for a single bundle.
  ///
  /// Returns a [_DownloadResult] containing collected progress events and
  /// the downloaded bytes. Throws on HTTP or network errors.
  Future<_DownloadResult> _executeDownload(
    ContentBundle bundle,
    StreamController<DownloadProgress> controller,
  ) async {
    final request = http.Request('GET', Uri.parse(bundle.url));
    final response = await _httpClient.send(request);

    if (response.statusCode != 200) {
      throw HttpDownloadException(
        'HTTP ${response.statusCode} for "${bundle.name}"',
        statusCode: response.statusCode,
      );
    }

    var downloaded = 0;
    final totalBytes = response.contentLength ?? bundle.sizeBytes;
    final startTime = DateTime.now();
    final bytesBuilder = BytesBuilder(copy: false);
    final progressEvents = <DownloadProgress>[];

    await for (final chunk in response.stream) {
      if (_isDisposed || !_activeDownloads.containsKey(bundle.name)) {
        return _DownloadResult(
          bytes: const [],
          totalBytes: totalBytes,
          progressEvents: progressEvents,
          cancelled: true,
        );
      }

      bytesBuilder.add(chunk);
      downloaded += chunk.length;

      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      final speed = elapsed > 0 ? (downloaded * 1000 ~/ elapsed) : 0;
      final remaining =
          speed > 0 ? ((totalBytes - downloaded) / speed).round() : 0;

      final progress = DownloadProgress(
        bundleName: bundle.name,
        downloadedBytes: downloaded,
        totalBytes: totalBytes,
        state: DownloadState.downloading,
        bytesPerSecond: speed,
        estimatedSecondsRemaining: remaining,
      );

      progressEvents.add(progress);
      controller.add(progress);
    }

    return _DownloadResult(
      bytes: bytesBuilder.takeBytes(),
      totalBytes: totalBytes,
      progressEvents: progressEvents,
    );
  }

  /// Download multiple bundles with concurrency limit.
  ///
  /// Each bundle emits its own progress events on the returned stream.
  /// Bundles are processed sequentially in the current implementation.
  ///
  /// [strategy] controls network conditions under which downloads proceed.
  /// [concurrency] overrides [maxConcurrency] for this call (reserved for
  /// future parallel implementation).
  Stream<DownloadProgress> downloadBundles(
    List<ContentBundle> bundles,
    DownloadStrategy strategy, {
    int? concurrency,
  }) async* {
    if (_isDisposed) return;

    if (!strategy.allowsAutoDownload) {
      UnityKitLogger.instance.debug(
        'Download strategy is manual; skipping batch download',
      );
      return;
    }

    for (final bundle in bundles) {
      if (_isDisposed) return;

      await for (final progress in downloadBundle(bundle)) {
        yield progress;
      }
    }
  }

  /// Cancel a specific download by bundle name.
  ///
  /// The download stream will emit a [DownloadState.cancelled] event.
  void cancelDownload(String bundleName) {
    final download = _activeDownloads.remove(bundleName);
    if (download != null) {
      download.controller.close();
      if (!download.completer.isCompleted) {
        download.completer.complete();
      }
      UnityKitLogger.instance.debug('Cancelled download "$bundleName"');
    }
  }

  /// Cancel all active downloads.
  void cancelAllDownloads() {
    final count = _activeDownloads.length;
    for (final download in _activeDownloads.values) {
      download.controller.close();
      if (!download.completer.isCompleted) {
        download.completer.complete();
      }
    }
    _activeDownloads.clear();
    if (count > 0) {
      UnityKitLogger.instance.debug('Cancelled $count active download(s)');
    }
  }

  /// Whether a bundle is currently being downloaded.
  bool isDownloading(String bundleName) {
    return _activeDownloads.containsKey(bundleName);
  }

  /// Number of active downloads.
  int get activeDownloadCount => _activeDownloads.length;

  /// Dispose the downloader, cancelling all active downloads.
  ///
  /// After calling dispose, no new downloads can be started.
  void dispose() {
    _isDisposed = true;
    for (final download in _activeDownloads.values) {
      download.controller.close();
      if (!download.completer.isCompleted) {
        download.completer.complete();
      }
    }
    _activeDownloads.clear();
    _httpClient.close();
    UnityKitLogger.instance.debug('ContentDownloader disposed');
  }

  void _cleanupDownload(String bundleName) {
    final download = _activeDownloads.remove(bundleName);
    if (download != null) {
      if (!download.completer.isCompleted) {
        download.completer.complete();
      }
      download.controller.close();
    }
  }
}

/// Result of a single download attempt.
class _DownloadResult {
  const _DownloadResult({
    required this.bytes,
    required this.totalBytes,
    required this.progressEvents,
    this.cancelled = false,
  });

  /// The downloaded bytes (empty if cancelled).
  final List<int> bytes;

  /// The total expected bytes.
  final int totalBytes;

  /// Progress events collected during the download.
  final List<DownloadProgress> progressEvents;

  /// Whether the download was cancelled.
  final bool cancelled;
}

/// Tracks an active download for cancellation support.
class _ActiveDownload {
  _ActiveDownload({
    required this.completer,
    required this.controller,
  });

  final Completer<void> completer;
  final StreamController<DownloadProgress> controller;
}

/// Exception thrown when an HTTP request fails.
///
/// Example:
/// ```dart
/// throw HttpDownloadException('HTTP 404 for "scene_main"', statusCode: 404);
/// ```
class HttpDownloadException implements Exception {
  /// Creates an [HttpDownloadException].
  const HttpDownloadException(this.message, {this.statusCode});

  /// A human-readable description of the error.
  final String message;

  /// The HTTP status code, if available.
  final int? statusCode;

  @override
  String toString() => 'HttpDownloadException: $message';
}
