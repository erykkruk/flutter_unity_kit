import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/logger.dart';

/// Manages local file cache for downloaded content bundles.
///
/// Stores bundle files on disk alongside a JSON manifest that tracks
/// SHA256 hashes, file sizes, and timestamps. Supports integrity
/// verification and stream-based caching for large files.
///
/// Example:
/// ```dart
/// final cache = CacheManager();
/// await cache.initialize();
///
/// await cache.cacheBundle('scene_main', bundleBytes);
/// final path = cache.getCachedBundlePath('scene_main');
/// ```
class CacheManager {
  /// Creates a [CacheManager].
  ///
  /// [cacheDirectoryName] controls the subdirectory name inside the
  /// platform cache directory. Defaults to `unity_kit_cache`.
  ///
  /// [cacheDirectory] allows injecting a specific directory, primarily
  /// for testing. When provided, [cacheDirectoryName] is ignored.
  CacheManager({
    String? cacheDirectoryName,
    Directory? cacheDirectory,
  })  : _cacheDirectoryName = cacheDirectoryName ?? _defaultCacheDirName,
        _injectedCacheDir = cacheDirectory;

  static const String _defaultCacheDirName = 'unity_kit_cache';
  static const String _manifestFilename = '_cache_manifest.json';

  final String _cacheDirectoryName;
  final Directory? _injectedCacheDir;
  Directory? _cacheDir;
  Map<String, CacheEntry> _manifest = {};
  bool _isInitialized = false;

  /// Whether the cache has been initialized.
  bool get isInitialized => _isInitialized;

  /// Initialize the cache (creates directory, loads manifest).
  ///
  /// Safe to call multiple times; subsequent calls are no-ops.
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (_injectedCacheDir != null) {
      _cacheDir = _injectedCacheDir;
    } else {
      final appDir = await getApplicationCacheDirectory();
      _cacheDir = Directory('${appDir.path}/$_cacheDirectoryName');
    }

    if (!_cacheDir!.existsSync()) {
      _cacheDir!.createSync(recursive: true);
    }

    await _loadManifest();
    _isInitialized = true;
    UnityKitLogger.instance.debug(
      'CacheManager initialized at ${_cacheDir!.path}',
    );
  }

  /// The absolute path to the cache directory.
  ///
  /// Throws [StateError] if not initialized.
  String get cachePath {
    _assertInitialized();
    return _cacheDir!.path;
  }

  /// Whether a bundle with [bundleName] exists in the manifest.
  bool isCached(String bundleName) {
    _assertInitialized();
    return _manifest.containsKey(bundleName);
  }

  /// Whether a bundle is cached and its SHA256 hash matches [sha256Hash].
  Future<bool> isCachedWithHash(String bundleName, String sha256Hash) async {
    _assertInitialized();
    final entry = _manifest[bundleName];
    if (entry == null) return false;
    return entry.sha256 == sha256Hash;
  }

  /// The file path for a cached bundle, or `null` if not cached.
  String? getCachedBundlePath(String bundleName) {
    _assertInitialized();
    if (!_manifest.containsKey(bundleName)) return null;
    return '${_cacheDir!.path}/$bundleName';
  }

  /// Cache [data] to disk under [bundleName].
  ///
  /// If [sha256Hash] is provided it is stored as-is; otherwise the
  /// hash is computed from [data].
  Future<void> cacheBundle(
    String bundleName,
    List<int> data, {
    String? sha256Hash,
  }) async {
    _assertInitialized();
    final file = File('${_cacheDir!.path}/$bundleName');
    await file.writeAsBytes(data);

    final hash = sha256Hash ?? sha256.convert(data).toString();
    _manifest[bundleName] = CacheEntry(
      sha256: hash,
      sizeBytes: data.length,
      cachedAt: DateTime.now(),
    );
    await _saveManifest();

    UnityKitLogger.instance.debug(
      'Cached bundle "$bundleName" (${data.length} bytes)',
    );
  }

  /// Cache bundle data arriving as a byte [stream].
  ///
  /// If [sha256Hash] is provided the computed hash is verified against
  /// it after the stream completes. On mismatch the written file is
  /// deleted and a [StateError] is thrown.
  Future<void> cacheBundleFromStream(
    String bundleName,
    Stream<List<int>> stream, {
    int? expectedSize,
    String? sha256Hash,
  }) async {
    _assertInitialized();
    final file = File('${_cacheDir!.path}/$bundleName');
    final sink = file.openWrite();
    final digestSink = _AccumulatorSink();
    final hashSink = sha256.startChunkedConversion(digestSink);
    var totalBytes = 0;

    try {
      await for (final chunk in stream) {
        sink.add(chunk);
        hashSink.add(chunk);
        totalBytes += chunk.length;
      }
      await sink.close();
      hashSink.close();
    } catch (e) {
      await sink.close();
      hashSink.close();
      if (file.existsSync()) file.deleteSync();
      rethrow;
    }

    final computedHash = digestSink.result.toString();
    final finalHash = sha256Hash ?? computedHash;

    if (sha256Hash != null && computedHash != sha256Hash) {
      file.deleteSync();
      throw StateError(
        'SHA256 mismatch: expected $sha256Hash, got $computedHash',
      );
    }

    _manifest[bundleName] = CacheEntry(
      sha256: finalHash,
      sizeBytes: totalBytes,
      cachedAt: DateTime.now(),
    );
    await _saveManifest();

    UnityKitLogger.instance.debug(
      'Cached bundle "$bundleName" from stream ($totalBytes bytes)',
    );
  }

  /// Remove a single bundle from cache.
  Future<void> removeBundle(String bundleName) async {
    _assertInitialized();
    final file = File('${_cacheDir!.path}/$bundleName');
    if (file.existsSync()) file.deleteSync();
    _manifest.remove(bundleName);
    await _saveManifest();

    UnityKitLogger.instance.debug('Removed cached bundle "$bundleName"');
  }

  /// Delete all cached data and reset the manifest.
  Future<void> clearCache() async {
    _assertInitialized();
    if (_cacheDir!.existsSync()) {
      _cacheDir!.deleteSync(recursive: true);
      _cacheDir!.createSync(recursive: true);
    }
    _manifest.clear();
    await _saveManifest();

    UnityKitLogger.instance.debug('Cache cleared');
  }

  /// Total size of all cached bundles in bytes.
  int getCacheSize() {
    _assertInitialized();
    var total = 0;
    for (final entry in _manifest.values) {
      total += entry.sizeBytes;
    }
    return total;
  }

  /// List of all cached bundle names.
  List<String> getCachedBundleNames() {
    _assertInitialized();
    return _manifest.keys.toList();
  }

  /// Verify cache integrity by checking every cached bundle.
  ///
  /// Returns the names of bundles that are missing from disk or
  /// whose SHA256 hash does not match the manifest entry.
  Future<List<String>> verifyCache() async {
    _assertInitialized();
    final invalid = <String>[];

    for (final entry in _manifest.entries) {
      final file = File('${_cacheDir!.path}/${entry.key}');

      if (!file.existsSync()) {
        invalid.add(entry.key);
        continue;
      }

      final bytes = file.readAsBytesSync();
      final hash = sha256.convert(bytes).toString();
      if (hash != entry.value.sha256) {
        invalid.add(entry.key);
      }
    }

    if (invalid.isNotEmpty) {
      UnityKitLogger.instance.warning(
        'Cache verification found ${invalid.length} invalid bundle(s)',
      );
    }

    return invalid;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _assertInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'CacheManager not initialized. Call initialize() first.',
      );
    }
  }

  File get _manifestFile => File('${_cacheDir!.path}/$_manifestFilename');

  Future<void> _loadManifest() async {
    final file = _manifestFile;
    if (!file.existsSync()) {
      _manifest = {};
      return;
    }

    try {
      final contents = file.readAsStringSync();
      final json = jsonDecode(contents) as Map<String, dynamic>;
      _manifest = json.map(
        (key, value) => MapEntry(
          key,
          CacheEntry.fromJson(value as Map<String, dynamic>),
        ),
      );
    } catch (e, stackTrace) {
      UnityKitLogger.instance.error(
        'Failed to load cache manifest, starting fresh',
        e,
        stackTrace,
      );
      _manifest = {};
    }
  }

  Future<void> _saveManifest() async {
    final json = _manifest.map(
      (key, value) => MapEntry(key, value.toJson()),
    );
    final contents = jsonEncode(json);
    _manifestFile.writeAsStringSync(contents);
  }
}

/// Entry in the cache manifest tracking a single cached bundle.
class CacheEntry {
  /// Creates a new [CacheEntry].
  const CacheEntry({
    required this.sha256,
    required this.sizeBytes,
    required this.cachedAt,
  });

  /// Creates a [CacheEntry] from a JSON map.
  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      sha256: json['sha256'] as String,
      sizeBytes: json['sizeBytes'] as int,
      cachedAt: DateTime.parse(json['cachedAt'] as String),
    );
  }

  /// The SHA256 hash of the cached file.
  final String sha256;

  /// The file size in bytes.
  final int sizeBytes;

  /// When the bundle was cached.
  final DateTime cachedAt;

  /// Serializes this entry to a JSON map.
  Map<String, dynamic> toJson() => {
        'sha256': sha256,
        'sizeBytes': sizeBytes,
        'cachedAt': cachedAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CacheEntry &&
          runtimeType == other.runtimeType &&
          sha256 == other.sha256 &&
          sizeBytes == other.sizeBytes;

  @override
  int get hashCode => sha256.hashCode ^ sizeBytes.hashCode;

  @override
  String toString() =>
      'CacheEntry(sha256: $sha256, sizeBytes: $sizeBytes, cachedAt: $cachedAt)';
}

/// Simple accumulator sink that stores the single [Digest] result from
/// a chunked hash conversion.
class _AccumulatorSink implements Sink<Digest> {
  Digest? _result;

  /// The computed digest. Only available after [close].
  Digest get result {
    if (_result == null) {
      throw StateError('No digest available yet. Was close() called?');
    }
    return _result!;
  }

  @override
  void add(Digest data) {
    _result = data;
  }

  @override
  void close() {
    // Nothing to clean up.
  }
}
