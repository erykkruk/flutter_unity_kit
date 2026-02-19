import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:mocktail/mocktail.dart';
import 'package:unity_kit/src/bridge/unity_bridge.dart';
import 'package:unity_kit/src/models/unity_message.dart';
import 'package:unity_kit/src/streaming/cache_manager.dart';
import 'package:unity_kit/src/streaming/models/models.dart';
import 'package:unity_kit/src/streaming/loaders/unity_bundle_loader.dart';
import 'package:unity_kit/src/streaming/streaming_controller.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockUnityBridge extends Mock implements UnityBridge {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const String _kManifestUrl = 'https://cdn.example.com/manifest.json';

/// Allows broadcast stream events to be delivered to listeners.
Future<void> _pumpEventQueue() async {
  await Future<void>.delayed(Duration.zero);
}

Map<String, dynamic> _buildManifestJson({
  List<Map<String, dynamic>>? bundles,
}) {
  return {
    'version': '1.0.0',
    'baseUrl': 'https://cdn.example.com/bundles',
    'bundles': bundles ??
        [
          {
            'name': 'core',
            'url': 'https://cdn.example.com/bundles/core.bin',
            'sizeBytes': 1024,
            'sha256': 'abc123',
            'isBase': true,
          },
          {
            'name': 'characters',
            'url': 'https://cdn.example.com/bundles/characters.bin',
            'sizeBytes': 2048,
            'sha256': 'def456',
            'isBase': false,
          },
        ],
  };
}

http_testing.MockClient _buildMockHttpClient({
  int manifestStatusCode = 200,
  Map<String, dynamic>? manifestJson,
  int downloadStatusCode = 200,
  List<int>? downloadBody,
}) {
  final manifest = manifestJson ?? _buildManifestJson();

  return http_testing.MockClient.streaming(
    (request, bodyStream) async {
      // Consume body stream to avoid resource leaks.
      await bodyStream.drain<void>();

      if (request.url.toString() == _kManifestUrl) {
        final body = utf8.encode(jsonEncode(manifest));
        return http.StreamedResponse(
          Stream.value(body),
          manifestStatusCode,
          request: request,
          contentLength: body.length,
        );
      }

      // Any other URL is treated as a bundle download.
      final body = downloadBody ?? utf8.encode('bundle_data');
      return http.StreamedResponse(
        Stream.value(body),
        downloadStatusCode,
        request: request,
        contentLength: body.length,
      );
    },
  );
}

void main() {
  late _MockUnityBridge bridge;
  late Directory tempDir;
  late CacheManager cacheManager;

  setUpAll(() {
    registerFallbackValue(const UnityMessage(type: 'fallback'));
  });

  setUp(() {
    bridge = _MockUnityBridge();
    when(() => bridge.sendWhenReady(any())).thenAnswer((_) async {});

    tempDir = Directory.systemTemp.createTempSync('streaming_ctrl_test_');
    cacheManager = CacheManager(cacheDirectory: tempDir);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // -------------------------------------------------------------------------
  // initialize()
  // -------------------------------------------------------------------------

  group('initialize()', () {
    test('fetches manifest and sets state to ready', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: client,
        cacheManager: cacheManager,
      );

      final states = <StreamingState>[];
      controller.stateChanges.listen(states.add);

      await controller.initialize();
      await _pumpEventQueue();

      expect(controller.state, StreamingState.ready);
      expect(states, contains(StreamingState.initializing));
      expect(states, contains(StreamingState.ready));

      await controller.dispose();
    });

    test('parses manifest correctly', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: client,
        cacheManager: cacheManager,
      );

      await controller.initialize();

      final manifest = controller.getManifest();
      expect(manifest, isNotNull);
      expect(manifest!.version, '1.0.0');
      expect(manifest.bundleCount, 2);

      await controller.dispose();
    });

    test('sends cache path to Unity', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: client,
        cacheManager: cacheManager,
      );

      await controller.initialize();

      final captured = verify(
        () => bridge.sendWhenReady(captureAny()),
      ).captured;

      expect(captured, isNotEmpty);
      final message = captured.first as UnityMessage;
      expect(message.gameObject, 'FlutterAddressablesManager');
      expect(message.method, 'SetCachePath');
      expect(message.data!['path'], tempDir.path);

      await controller.dispose();
    });

    test('sets state to error on HTTP failure', () async {
      final client = _buildMockHttpClient(manifestStatusCode: 500);
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: client,
        cacheManager: cacheManager,
      );

      final errors = <StreamingError>[];
      controller.errors.listen(errors.add);

      await controller.initialize();
      await _pumpEventQueue();

      expect(controller.state, StreamingState.error);
      expect(errors, hasLength(1));
      expect(errors.first.type, StreamingErrorType.initializationFailed);

      await controller.dispose();
    });

    test('does nothing when already disposed', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: client,
        cacheManager: cacheManager,
      );

      await controller.dispose();
      await controller.initialize();

      expect(controller.state, StreamingState.uninitialized);
    });
  });

  // -------------------------------------------------------------------------
  // getManifest()
  // -------------------------------------------------------------------------

  group('getManifest()', () {
    test('returns null before initialization', () {
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: _buildMockHttpClient(),
        cacheManager: cacheManager,
      );

      expect(controller.getManifest(), isNull);
    });

    test('returns parsed manifest after initialization', () async {
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: _buildMockHttpClient(),
        cacheManager: cacheManager,
      );

      await controller.initialize();

      final manifest = controller.getManifest();
      expect(manifest, isNotNull);
      expect(manifest!.bundles, hasLength(2));

      await controller.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // preloadContent()
  // -------------------------------------------------------------------------

  group('preloadContent()', () {
    test('downloads uncached bundles', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: client,
        cacheManager: cacheManager,
      );
      await controller.initialize();

      final progress = <DownloadProgress>[];
      controller.downloadProgress.listen(progress.add);

      await controller.preloadContent(bundles: ['core']);
      await _pumpEventQueue();

      final completed =
          progress.where((p) => p.state == DownloadState.completed);
      expect(completed, isNotEmpty);
      expect(completed.first.bundleName, 'core');
      expect(controller.state, StreamingState.ready);

      await controller.dispose();
    });

    test('skips already cached bundles', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: client,
        cacheManager: cacheManager,
      );
      await controller.initialize();

      // Pre-cache the bundle.
      await cacheManager.cacheBundle('core', utf8.encode('cached_data'));

      final progress = <DownloadProgress>[];
      controller.downloadProgress.listen(progress.add);

      await controller.preloadContent(bundles: ['core']);
      await _pumpEventQueue();

      expect(progress, hasLength(1));
      expect(progress.first.state, DownloadState.cached);

      await controller.dispose();
    });

    test('defaults to base bundles when no list provided', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: client,
        cacheManager: cacheManager,
      );
      await controller.initialize();

      final progress = <DownloadProgress>[];
      controller.downloadProgress.listen(progress.add);

      // Default preload targets base bundles only (core is isBase: true).
      await controller.preloadContent();
      await _pumpEventQueue();

      final completedNames = progress
          .where((p) => p.state == DownloadState.completed)
          .map((p) => p.bundleName)
          .toList();
      expect(completedNames, contains('core'));
      // 'characters' is not isBase, so should not be downloaded.
      expect(completedNames, isNot(contains('characters')));

      await controller.dispose();
    });

    test('throws StateError when not initialized', () {
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: _buildMockHttpClient(),
        cacheManager: cacheManager,
      );

      expect(
        () => controller.preloadContent(),
        throwsStateError,
      );
    });
  });

  // -------------------------------------------------------------------------
  // loadBundle()
  // -------------------------------------------------------------------------

  group('loadBundle()', () {
    test('downloads and sends LoadAsset to Unity', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: client,
        cacheManager: cacheManager,
      );
      await controller.initialize();

      // Reset invocations after initialize sent SetCachePath.
      clearInteractions(bridge);
      when(() => bridge.sendWhenReady(any())).thenAnswer((_) async {});

      await controller.loadBundle('characters');

      final captured = verify(
        () => bridge.sendWhenReady(captureAny()),
      ).captured;

      expect(captured, isNotEmpty);
      final message = captured.first as UnityMessage;
      expect(message.gameObject, 'FlutterAddressablesManager');
      expect(message.method, 'LoadAsset');
      expect(message.data!['key'], 'characters');
      expect(message.data!['callbackId'], 'load_characters');

      await controller.dispose();
    });

    test('emits error for unknown bundle', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: client,
        cacheManager: cacheManager,
      );
      await controller.initialize();

      final errors = <StreamingError>[];
      controller.errors.listen(errors.add);

      await controller.loadBundle('nonexistent');
      await _pumpEventQueue();

      expect(errors, hasLength(1));
      expect(errors.first.type, StreamingErrorType.bundleNotFound);
      expect(errors.first.message, contains('nonexistent'));

      await controller.dispose();
    });

    test('skips download when bundle is already cached', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: client,
        cacheManager: cacheManager,
      );
      await controller.initialize();

      // Pre-cache the bundle.
      await cacheManager.cacheBundle(
        'characters',
        utf8.encode('cached_chars'),
      );

      final progress = <DownloadProgress>[];
      controller.downloadProgress.listen(progress.add);

      clearInteractions(bridge);
      when(() => bridge.sendWhenReady(any())).thenAnswer((_) async {});

      await controller.loadBundle('characters');
      await _pumpEventQueue();

      // No download progress emitted (already cached).
      expect(
        progress.where((p) => p.state == DownloadState.downloading),
        isEmpty,
      );

      // But Unity LoadAsset was still sent.
      verify(() => bridge.sendWhenReady(any())).called(1);

      await controller.dispose();
    });

    test('throws StateError when not initialized', () {
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: _buildMockHttpClient(),
        cacheManager: cacheManager,
      );

      expect(
        () => controller.loadBundle('core'),
        throwsStateError,
      );
    });
  });

  // -------------------------------------------------------------------------
  // loadScene()
  // -------------------------------------------------------------------------

  group('loadScene()', () {
    test('sends LoadScene message to Unity', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: client,
        cacheManager: cacheManager,
      );
      await controller.initialize();

      clearInteractions(bridge);
      when(() => bridge.sendWhenReady(any())).thenAnswer((_) async {});

      await controller.loadScene('core');

      final captured = verify(
        () => bridge.sendWhenReady(captureAny()),
      ).captured;

      expect(captured, isNotEmpty);
      final message = captured.first as UnityMessage;
      expect(message.method, 'LoadScene');
      expect(message.data!['sceneName'], 'core');
      expect(message.data!['loadMode'], 'Single');

      await controller.dispose();
    });

    test('passes custom loadMode', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: client,
        cacheManager: cacheManager,
      );
      await controller.initialize();

      clearInteractions(bridge);
      when(() => bridge.sendWhenReady(any())).thenAnswer((_) async {});

      await controller.loadScene('core', loadMode: 'Additive');

      final captured = verify(
        () => bridge.sendWhenReady(captureAny()),
      ).captured;

      final message = captured.first as UnityMessage;
      expect(message.data!['loadMode'], 'Additive');

      await controller.dispose();
    });

    test('works when scene has no matching bundle', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: client,
        cacheManager: cacheManager,
      );
      await controller.initialize();

      clearInteractions(bridge);
      when(() => bridge.sendWhenReady(any())).thenAnswer((_) async {});

      // 'unknown_scene' is not in the manifest, but loadScene
      // should still send the message to Unity.
      await controller.loadScene('unknown_scene');

      verify(() => bridge.sendWhenReady(any())).called(1);

      await controller.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // Cache delegation
  // -------------------------------------------------------------------------

  group('cache delegation', () {
    test('getCachedBundles returns cache contents', () async {
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: _buildMockHttpClient(),
        cacheManager: cacheManager,
      );
      await controller.initialize();

      await cacheManager.cacheBundle('alpha', utf8.encode('a'));
      await cacheManager.cacheBundle('beta', utf8.encode('b'));

      final cached = controller.getCachedBundles();
      expect(cached, containsAll(['alpha', 'beta']));

      await controller.dispose();
    });

    test('isBundleCached checks correctly', () async {
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: _buildMockHttpClient(),
        cacheManager: cacheManager,
      );
      await controller.initialize();

      await cacheManager.cacheBundle('existing', utf8.encode('data'));

      expect(controller.isBundleCached('existing'), isTrue);
      expect(controller.isBundleCached('missing'), isFalse);

      await controller.dispose();
    });

    test('getCacheSize delegates to cache manager', () async {
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: _buildMockHttpClient(),
        cacheManager: cacheManager,
      );
      await controller.initialize();

      await cacheManager.cacheBundle('sized', utf8.encode('12345'));

      expect(controller.getCacheSize(), 5);

      await controller.dispose();
    });

    test('clearCache delegates to cache manager', () async {
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: _buildMockHttpClient(),
        cacheManager: cacheManager,
      );
      await controller.initialize();

      await cacheManager.cacheBundle('to_clear', utf8.encode('x'));
      expect(cacheManager.getCachedBundleNames(), isNotEmpty);

      await controller.clearCache();

      expect(cacheManager.getCachedBundleNames(), isEmpty);

      await controller.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // State and error streams
  // -------------------------------------------------------------------------

  group('state and error streams', () {
    test('state changes are emitted on stateChanges stream', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: client,
        cacheManager: cacheManager,
      );

      final states = <StreamingState>[];
      controller.stateChanges.listen(states.add);

      await controller.initialize();
      await _pumpEventQueue();

      expect(states, [StreamingState.initializing, StreamingState.ready]);

      await controller.dispose();
    });

    test('errors are emitted on errors stream', () async {
      final client = _buildMockHttpClient(manifestStatusCode: 404);
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: client,
        cacheManager: cacheManager,
      );

      final errors = <StreamingError>[];
      controller.errors.listen(errors.add);

      await controller.initialize();
      await _pumpEventQueue();

      expect(errors, hasLength(1));
      expect(errors.first.type, StreamingErrorType.initializationFailed);
      expect(errors.first.cause, isNotNull);

      await controller.dispose();
    });

    test('download failure emits error and failed progress', () async {
      final client = _buildMockHttpClient(downloadStatusCode: 500);
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: client,
        cacheManager: cacheManager,
      );
      await controller.initialize();

      final errors = <StreamingError>[];
      final progress = <DownloadProgress>[];
      controller.errors.listen(errors.add);
      controller.downloadProgress.listen(progress.add);

      await controller.preloadContent(bundles: ['core']);
      await _pumpEventQueue();

      expect(errors, isNotEmpty);
      expect(errors.first.type, StreamingErrorType.downloadFailed);

      final failed = progress.where((p) => p.state == DownloadState.failed);
      expect(failed, isNotEmpty);

      await controller.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // dispose()
  // -------------------------------------------------------------------------

  group('dispose()', () {
    test('prevents further operations', () async {
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: _buildMockHttpClient(),
        cacheManager: cacheManager,
      );
      await controller.initialize();
      await controller.dispose();

      expect(controller.isDisposed, isTrue);
      expect(
        () => controller.loadBundle('core'),
        throwsStateError,
      );
    });

    test('is idempotent', () async {
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: _buildMockHttpClient(),
        cacheManager: cacheManager,
      );

      await controller.dispose();
      await controller.dispose();

      expect(controller.isDisposed, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Custom asset loader injection
  // -------------------------------------------------------------------------

  group('custom asset loader', () {
    test('defaults to UnityAddressablesLoader', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: client,
        cacheManager: cacheManager,
      );

      expect(controller.assetLoader.targetName, 'FlutterAddressablesManager');

      await controller.dispose();
    });

    test('accepts custom UnityBundleLoader', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        assetLoader: const UnityBundleLoader(),
        httpClient: client,
        cacheManager: cacheManager,
      );

      expect(controller.assetLoader.targetName, 'FlutterAssetBundleManager');

      await controller.dispose();
    });

    test('uses custom loader for SetCachePath on initialize', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        assetLoader: const UnityBundleLoader(),
        httpClient: client,
        cacheManager: cacheManager,
      );

      await controller.initialize();

      final captured = verify(
        () => bridge.sendWhenReady(captureAny()),
      ).captured;

      expect(captured, isNotEmpty);
      final message = captured.first as UnityMessage;
      expect(message.gameObject, 'FlutterAssetBundleManager');
      expect(message.method, 'SetCachePath');

      await controller.dispose();
    });

    test('uses custom loader for loadBundle', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        assetLoader: const UnityBundleLoader(),
        httpClient: client,
        cacheManager: cacheManager,
      );
      await controller.initialize();

      clearInteractions(bridge);
      when(() => bridge.sendWhenReady(any())).thenAnswer((_) async {});

      await controller.loadBundle('characters');

      final captured = verify(
        () => bridge.sendWhenReady(captureAny()),
      ).captured;

      expect(captured, isNotEmpty);
      final message = captured.first as UnityMessage;
      expect(message.gameObject, 'FlutterAssetBundleManager');
      expect(message.method, 'LoadBundle');
      expect(message.data!['bundleName'], 'characters');

      await controller.dispose();
    });

    test('uses custom loader for loadScene', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        assetLoader: const UnityBundleLoader(),
        httpClient: client,
        cacheManager: cacheManager,
      );
      await controller.initialize();

      clearInteractions(bridge);
      when(() => bridge.sendWhenReady(any())).thenAnswer((_) async {});

      await controller.loadScene('core', loadMode: 'Additive');

      final captured = verify(
        () => bridge.sendWhenReady(captureAny()),
      ).captured;

      expect(captured, isNotEmpty);
      final message = captured.first as UnityMessage;
      expect(message.gameObject, 'FlutterAssetBundleManager');
      expect(message.method, 'LoadScene');
      expect(message.data!['bundleName'], 'core');
      expect(message.data!['loadMode'], 'Additive');

      await controller.dispose();
    });

    test('BundleLoader loadBundle skips download when cached', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        assetLoader: const UnityBundleLoader(),
        httpClient: client,
        cacheManager: cacheManager,
      );
      await controller.initialize();

      await cacheManager.cacheBundle(
        'characters',
        utf8.encode('cached_data'),
      );

      final progress = <DownloadProgress>[];
      controller.downloadProgress.listen(progress.add);

      clearInteractions(bridge);
      when(() => bridge.sendWhenReady(any())).thenAnswer((_) async {});

      await controller.loadBundle('characters');
      await _pumpEventQueue();

      // No download happened.
      expect(
        progress.where((p) => p.state == DownloadState.downloading),
        isEmpty,
      );

      // But LoadBundle was still sent to Unity.
      final captured = verify(
        () => bridge.sendWhenReady(captureAny()),
      ).captured;
      final message = captured.first as UnityMessage;
      expect(message.method, 'LoadBundle');

      await controller.dispose();
    });

    test('BundleLoader preloadContent downloads and emits progress', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        assetLoader: const UnityBundleLoader(),
        httpClient: client,
        cacheManager: cacheManager,
      );
      await controller.initialize();

      final progress = <DownloadProgress>[];
      controller.downloadProgress.listen(progress.add);

      await controller.preloadContent(bundles: ['core']);
      await _pumpEventQueue();

      final completed =
          progress.where((p) => p.state == DownloadState.completed);
      expect(completed, isNotEmpty);
      expect(completed.first.bundleName, 'core');
      expect(controller.state, StreamingState.ready);

      await controller.dispose();
    });

    test('BundleLoader emits error for unknown bundle', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        assetLoader: const UnityBundleLoader(),
        httpClient: client,
        cacheManager: cacheManager,
      );
      await controller.initialize();

      final errors = <StreamingError>[];
      controller.errors.listen(errors.add);

      await controller.loadBundle('nonexistent');
      await _pumpEventQueue();

      expect(errors, hasLength(1));
      expect(errors.first.type, StreamingErrorType.bundleNotFound);

      await controller.dispose();
    });

    test('BundleLoader download failure emits error', () async {
      final client = _buildMockHttpClient(downloadStatusCode: 500);
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        assetLoader: const UnityBundleLoader(),
        httpClient: client,
        cacheManager: cacheManager,
      );
      await controller.initialize();

      final errors = <StreamingError>[];
      final progress = <DownloadProgress>[];
      controller.errors.listen(errors.add);
      controller.downloadProgress.listen(progress.add);

      await controller.preloadContent(bundles: ['core']);
      await _pumpEventQueue();

      expect(errors, isNotEmpty);
      expect(errors.first.type, StreamingErrorType.downloadFailed);

      final failed = progress.where((p) => p.state == DownloadState.failed);
      expect(failed, isNotEmpty);

      await controller.dispose();
    });

    test('BundleLoader loadScene with Single mode', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        assetLoader: const UnityBundleLoader(),
        httpClient: client,
        cacheManager: cacheManager,
      );
      await controller.initialize();

      clearInteractions(bridge);
      when(() => bridge.sendWhenReady(any())).thenAnswer((_) async {});

      await controller.loadScene('core');

      final captured = verify(
        () => bridge.sendWhenReady(captureAny()),
      ).captured;

      final message = captured.first as UnityMessage;
      expect(message.data!['loadMode'], 'Single');
      expect(message.data!['bundleName'], 'core');

      await controller.dispose();
    });

    test('BundleLoader loadScene with unknown scene sends message', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        assetLoader: const UnityBundleLoader(),
        httpClient: client,
        cacheManager: cacheManager,
      );
      await controller.initialize();

      clearInteractions(bridge);
      when(() => bridge.sendWhenReady(any())).thenAnswer((_) async {});

      await controller.loadScene('unknown_scene');

      verify(() => bridge.sendWhenReady(any())).called(1);

      await controller.dispose();
    });

    test('BundleLoader cache delegation works the same', () async {
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        assetLoader: const UnityBundleLoader(),
        httpClient: _buildMockHttpClient(),
        cacheManager: cacheManager,
      );
      await controller.initialize();

      await cacheManager.cacheBundle('alpha', utf8.encode('a'));
      await cacheManager.cacheBundle('beta', utf8.encode('b'));

      expect(controller.getCachedBundles(), containsAll(['alpha', 'beta']));
      expect(controller.isBundleCached('alpha'), isTrue);
      expect(controller.isBundleCached('missing'), isFalse);
      expect(controller.getCacheSize(), 2);

      await controller.clearCache();
      expect(controller.getCachedBundles(), isEmpty);

      await controller.dispose();
    });

    test('BundleLoader state transitions match Addressables', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        assetLoader: const UnityBundleLoader(),
        httpClient: client,
        cacheManager: cacheManager,
      );

      final states = <StreamingState>[];
      controller.stateChanges.listen(states.add);

      await controller.initialize();
      await _pumpEventQueue();

      expect(states, [StreamingState.initializing, StreamingState.ready]);

      await controller.dispose();
    });

    test('BundleLoader init failure sets error state', () async {
      final client = _buildMockHttpClient(manifestStatusCode: 500);
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        assetLoader: const UnityBundleLoader(),
        httpClient: client,
        cacheManager: cacheManager,
      );

      final errors = <StreamingError>[];
      controller.errors.listen(errors.add);

      await controller.initialize();
      await _pumpEventQueue();

      expect(controller.state, StreamingState.error);
      expect(errors, hasLength(1));
      expect(errors.first.type, StreamingErrorType.initializationFailed);

      await controller.dispose();
    });

    test('BundleLoader throws StateError when not initialized', () {
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        assetLoader: const UnityBundleLoader(),
        httpClient: _buildMockHttpClient(),
        cacheManager: cacheManager,
      );

      expect(() => controller.loadBundle('core'), throwsStateError);
      expect(() => controller.loadScene('core'), throwsStateError);
      expect(() => controller.preloadContent(), throwsStateError);
    });
  });

  // -------------------------------------------------------------------------
  // URL validation
  // -------------------------------------------------------------------------

  group('URL validation', () {
    test('rejects manifest URL without scheme', () {
      expect(
        () => StreamingController(
          bridge: bridge,
          manifestUrl: 'cdn.example.com/manifest.json',
          httpClient: _buildMockHttpClient(),
          cacheManager: cacheManager,
        ),
        throwsArgumentError,
      );
    });

    test('rejects manifest URL with file scheme', () {
      expect(
        () => StreamingController(
          bridge: bridge,
          manifestUrl: 'file:///etc/passwd',
          httpClient: _buildMockHttpClient(),
          cacheManager: cacheManager,
        ),
        throwsArgumentError,
      );
    });

    test('rejects manifest URL with ftp scheme', () {
      expect(
        () => StreamingController(
          bridge: bridge,
          manifestUrl: 'ftp://cdn.example.com/manifest.json',
          httpClient: _buildMockHttpClient(),
          cacheManager: cacheManager,
        ),
        throwsArgumentError,
      );
    });

    test('accepts HTTP manifest URL', () {
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: 'http://cdn.example.com/manifest.json',
        httpClient: _buildMockHttpClient(),
        cacheManager: cacheManager,
      );

      expect(controller.state, StreamingState.uninitialized);
    });

    test('accepts HTTPS manifest URL', () {
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: _buildMockHttpClient(),
        cacheManager: cacheManager,
      );

      expect(controller.state, StreamingState.uninitialized);
    });

    test('rejects empty manifest URL', () {
      expect(
        () => StreamingController(
          bridge: bridge,
          manifestUrl: '',
          httpClient: _buildMockHttpClient(),
          cacheManager: cacheManager,
        ),
        throwsArgumentError,
      );
    });

    test('emits error when bundle URL in manifest is invalid', () async {
      final badBundleManifest = _buildManifestJson(bundles: [
        {
          'name': 'bad_bundle',
          'url': 'not-a-url',
          'sizeBytes': 512,
          'sha256': 'abc',
          'isBase': true,
        },
      ]);

      final client = _buildMockHttpClient(manifestJson: badBundleManifest);
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: client,
        cacheManager: cacheManager,
      );
      await controller.initialize();

      final errors = <StreamingError>[];
      controller.errors.listen(errors.add);

      await controller.preloadContent(bundles: ['bad_bundle']);
      await _pumpEventQueue();

      expect(errors, isNotEmpty);
      expect(errors.first.type, StreamingErrorType.downloadFailed);

      await controller.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // Download progress with BytesBuilder
  // -------------------------------------------------------------------------

  group('download progress tracking', () {
    test('emits progress events during download', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: client,
        cacheManager: cacheManager,
      );
      await controller.initialize();

      final progress = <DownloadProgress>[];
      controller.downloadProgress.listen(progress.add);

      await controller.loadBundle('characters');
      await _pumpEventQueue();

      final downloading =
          progress.where((p) => p.state == DownloadState.downloading);
      final completed =
          progress.where((p) => p.state == DownloadState.completed);

      expect(downloading, isNotEmpty);
      expect(completed, hasLength(1));
      expect(completed.first.bundleName, 'characters');

      await controller.dispose();
    });

    test('downloadedBytes increments during download', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: client,
        cacheManager: cacheManager,
      );
      await controller.initialize();

      final progress = <DownloadProgress>[];
      controller.downloadProgress.listen(progress.add);

      await controller.loadBundle('core');
      await _pumpEventQueue();

      final downloading =
          progress.where((p) => p.state == DownloadState.downloading).toList();

      if (downloading.isNotEmpty) {
        expect(downloading.last.downloadedBytes, greaterThan(0));
      }

      await controller.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // Dispose during download
  // -------------------------------------------------------------------------

  group('dispose during operations', () {
    test('stops preload when disposed mid-operation', () async {
      final client = _buildMockHttpClient();
      final controller = StreamingController(
        bridge: bridge,
        manifestUrl: _kManifestUrl,
        httpClient: client,
        cacheManager: cacheManager,
      );
      await controller.initialize();

      // Start preload and immediately dispose.
      final preloadFuture =
          controller.preloadContent(bundles: ['core', 'characters']);
      await controller.dispose();
      await preloadFuture;

      expect(controller.isDisposed, isTrue);
    });
  });
}
