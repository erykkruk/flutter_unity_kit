import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/streaming/cache_manager.dart';

void main() {
  group('CacheManager', () {
    late Directory tempDir;
    late CacheManager cacheManager;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('cache_manager_test_');
      cacheManager = CacheManager(cacheDirectory: tempDir);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    group('initialize()', () {
      test('creates cache directory', () async {
        // Use a subdirectory that does not exist yet.
        final subDir = Directory('${tempDir.path}/new_sub');
        final manager = CacheManager(cacheDirectory: subDir);

        await manager.initialize();

        expect(subDir.existsSync(), isTrue);
        expect(manager.isInitialized, isTrue);
      });

      test('is idempotent', () async {
        await cacheManager.initialize();
        await cacheManager.initialize();

        expect(cacheManager.isInitialized, isTrue);
      });

      test('loads existing manifest on second initialization', () async {
        await cacheManager.initialize();
        final data = utf8.encode('hello');
        await cacheManager.cacheBundle('bundle_a', data);

        // Create a new manager pointed at the same directory.
        final secondManager = CacheManager(cacheDirectory: tempDir);
        await secondManager.initialize();

        expect(secondManager.isCached('bundle_a'), isTrue);
      });
    });

    group('cacheBundle()', () {
      test('writes file and adds manifest entry', () async {
        await cacheManager.initialize();
        final data = utf8.encode('bundle content');

        await cacheManager.cacheBundle('scene_main', data);

        final file = File('${tempDir.path}/scene_main');
        expect(file.existsSync(), isTrue);
        expect(file.readAsBytesSync(), data);
        expect(cacheManager.isCached('scene_main'), isTrue);
      });

      test('computes SHA256 when hash not provided', () async {
        await cacheManager.initialize();
        final data = utf8.encode('content');
        final expectedHash = sha256.convert(data).toString();

        await cacheManager.cacheBundle('bundle_x', data);

        final matches =
            await cacheManager.isCachedWithHash('bundle_x', expectedHash);
        expect(matches, isTrue);
      });

      test('stores provided SHA256 hash as-is', () async {
        await cacheManager.initialize();
        final data = utf8.encode('content');
        const customHash = 'custom_hash_value';

        await cacheManager.cacheBundle('bundle_y', data,
            sha256Hash: customHash);

        final matches =
            await cacheManager.isCachedWithHash('bundle_y', customHash);
        expect(matches, isTrue);
      });
    });

    group('isCached()', () {
      test('returns true for cached bundles', () async {
        await cacheManager.initialize();
        await cacheManager.cacheBundle('cached_one', utf8.encode('data'));

        expect(cacheManager.isCached('cached_one'), isTrue);
      });

      test('returns false for unknown bundles', () async {
        await cacheManager.initialize();

        expect(cacheManager.isCached('nonexistent'), isFalse);
      });
    });

    group('getCachedBundlePath()', () {
      test('returns correct path for cached bundle', () async {
        await cacheManager.initialize();
        await cacheManager.cacheBundle('my_bundle', utf8.encode('abc'));

        final path = cacheManager.getCachedBundlePath('my_bundle');

        expect(path, '${tempDir.path}/my_bundle');
      });

      test('returns null for uncached bundle', () async {
        await cacheManager.initialize();

        expect(cacheManager.getCachedBundlePath('missing'), isNull);
      });
    });

    group('isCachedWithHash()', () {
      test('returns true when hash matches', () async {
        await cacheManager.initialize();
        final data = utf8.encode('verify me');
        final hash = sha256.convert(data).toString();

        await cacheManager.cacheBundle('verifiable', data);

        expect(
          await cacheManager.isCachedWithHash('verifiable', hash),
          isTrue,
        );
      });

      test('returns false when hash does not match', () async {
        await cacheManager.initialize();
        await cacheManager.cacheBundle('verifiable', utf8.encode('content'));

        expect(
          await cacheManager.isCachedWithHash('verifiable', 'wrong_hash'),
          isFalse,
        );
      });

      test('returns false for uncached bundle', () async {
        await cacheManager.initialize();

        expect(
          await cacheManager.isCachedWithHash('none', 'any_hash'),
          isFalse,
        );
      });
    });

    group('cacheBundleFromStream()', () {
      test('writes stream data to file', () async {
        await cacheManager.initialize();
        final chunks = [utf8.encode('chunk1'), utf8.encode('chunk2')];
        final stream = Stream.fromIterable(chunks);
        final allData = [...chunks[0], ...chunks[1]];

        await cacheManager.cacheBundleFromStream('streamed', stream);

        final file = File('${tempDir.path}/streamed');
        expect(file.readAsBytesSync(), allData);
        expect(cacheManager.isCached('streamed'), isTrue);
      });

      test('throws StateError on SHA256 mismatch', () async {
        await cacheManager.initialize();
        final stream = Stream.fromIterable([utf8.encode('data')]);

        expect(
          () => cacheManager.cacheBundleFromStream(
            'bad_hash',
            stream,
            sha256Hash: 'definitely_wrong_hash',
          ),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('SHA256 mismatch'),
          )),
        );
      });

      test('deletes file on SHA256 mismatch', () async {
        await cacheManager.initialize();
        final stream = Stream.fromIterable([utf8.encode('data')]);

        try {
          await cacheManager.cacheBundleFromStream(
            'bad_hash',
            stream,
            sha256Hash: 'wrong_hash',
          );
        } catch (_) {
          // Expected.
        }

        final file = File('${tempDir.path}/bad_hash');
        expect(file.existsSync(), isFalse);
      });

      test('validates matching SHA256 hash succeeds', () async {
        await cacheManager.initialize();
        final data = utf8.encode('valid data');
        final hash = sha256.convert(data).toString();
        final stream = Stream.fromIterable([data]);

        await cacheManager.cacheBundleFromStream(
          'valid_stream',
          stream,
          sha256Hash: hash,
        );

        expect(cacheManager.isCached('valid_stream'), isTrue);
      });
    });

    group('removeBundle()', () {
      test('deletes file and manifest entry', () async {
        await cacheManager.initialize();
        await cacheManager.cacheBundle('to_remove', utf8.encode('bye'));

        await cacheManager.removeBundle('to_remove');

        final file = File('${tempDir.path}/to_remove');
        expect(file.existsSync(), isFalse);
        expect(cacheManager.isCached('to_remove'), isFalse);
      });

      test('succeeds for non-existent bundle', () async {
        await cacheManager.initialize();

        // Should not throw.
        await cacheManager.removeBundle('never_existed');
      });
    });

    group('clearCache()', () {
      test('removes all files and resets manifest', () async {
        await cacheManager.initialize();
        await cacheManager.cacheBundle('a', utf8.encode('1'));
        await cacheManager.cacheBundle('b', utf8.encode('2'));

        await cacheManager.clearCache();

        expect(cacheManager.getCachedBundleNames(), isEmpty);
        expect(File('${tempDir.path}/a').existsSync(), isFalse);
        expect(File('${tempDir.path}/b').existsSync(), isFalse);
      });
    });

    group('getCacheSize()', () {
      test('returns correct total size', () async {
        await cacheManager.initialize();
        final data1 = utf8.encode('hello'); // 5 bytes
        final data2 = utf8.encode('world!'); // 6 bytes

        await cacheManager.cacheBundle('first', data1);
        await cacheManager.cacheBundle('second', data2);

        final size = cacheManager.getCacheSize();
        expect(size, 11);
      });

      test('returns zero when empty', () async {
        await cacheManager.initialize();

        expect(cacheManager.getCacheSize(), 0);
      });
    });

    group('getCachedBundleNames()', () {
      test('returns list of all cached bundle names', () async {
        await cacheManager.initialize();
        await cacheManager.cacheBundle('alpha', utf8.encode('a'));
        await cacheManager.cacheBundle('beta', utf8.encode('b'));

        final names = cacheManager.getCachedBundleNames();

        expect(names, containsAll(['alpha', 'beta']));
        expect(names, hasLength(2));
      });

      test('returns empty list when no bundles cached', () async {
        await cacheManager.initialize();

        expect(cacheManager.getCachedBundleNames(), isEmpty);
      });
    });

    group('verifyCache()', () {
      test('returns empty list for valid cache', () async {
        await cacheManager.initialize();
        await cacheManager.cacheBundle('valid', utf8.encode('ok'));

        final invalid = await cacheManager.verifyCache();

        expect(invalid, isEmpty);
      });

      test('detects missing files', () async {
        await cacheManager.initialize();
        await cacheManager.cacheBundle('will_delete', utf8.encode('gone'));

        // Manually delete the file but leave the manifest entry.
        File('${tempDir.path}/will_delete').deleteSync();

        final invalid = await cacheManager.verifyCache();

        expect(invalid, contains('will_delete'));
      });

      test('detects corrupted files (wrong hash)', () async {
        await cacheManager.initialize();
        await cacheManager.cacheBundle('corrupted', utf8.encode('original'));

        // Overwrite file content to corrupt it.
        File('${tempDir.path}/corrupted').writeAsStringSync('tampered');

        final invalid = await cacheManager.verifyCache();

        expect(invalid, contains('corrupted'));
      });
    });

    group('cachePath', () {
      test('returns correct path after initialization', () async {
        await cacheManager.initialize();

        expect(cacheManager.cachePath, tempDir.path);
      });
    });

    group('uninitialized guard', () {
      test('cachePath throws StateError', () {
        expect(() => cacheManager.cachePath, throwsStateError);
      });

      test('isCached throws StateError', () {
        expect(() => cacheManager.isCached('x'), throwsStateError);
      });

      test('isCachedWithHash throws StateError', () {
        expect(
          () => cacheManager.isCachedWithHash('x', 'h'),
          throwsStateError,
        );
      });

      test('getCachedBundlePath throws StateError', () {
        expect(() => cacheManager.getCachedBundlePath('x'), throwsStateError);
      });

      test('cacheBundle throws StateError', () {
        expect(
          () => cacheManager.cacheBundle('x', [1, 2, 3]),
          throwsStateError,
        );
      });

      test('cacheBundleFromStream throws StateError', () {
        expect(
          () => cacheManager.cacheBundleFromStream(
            'x',
            Stream.fromIterable([]),
          ),
          throwsStateError,
        );
      });

      test('removeBundle throws StateError', () {
        expect(() => cacheManager.removeBundle('x'), throwsStateError);
      });

      test('clearCache throws StateError', () {
        expect(() => cacheManager.clearCache(), throwsStateError);
      });

      test('getCacheSize throws StateError', () {
        expect(cacheManager.getCacheSize, throwsStateError);
      });

      test('getCachedBundleNames throws StateError', () {
        expect(() => cacheManager.getCachedBundleNames(), throwsStateError);
      });

      test('verifyCache throws StateError', () {
        expect(() => cacheManager.verifyCache(), throwsStateError);
      });
    });
  });

  group('CacheEntry', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final entry = CacheEntry(
          sha256: 'abc123',
          sizeBytes: 1024,
          cachedAt: DateTime(2025, 1, 15),
        );

        expect(entry.sha256, 'abc123');
        expect(entry.sizeBytes, 1024);
        expect(entry.cachedAt, DateTime(2025, 1, 15));
      });
    });

    group('fromJson', () {
      test('parses valid JSON', () {
        final entry = CacheEntry.fromJson({
          'sha256': 'hash_value',
          'sizeBytes': 2048,
          'cachedAt': '2025-01-15T10:30:00.000Z',
        });

        expect(entry.sha256, 'hash_value');
        expect(entry.sizeBytes, 2048);
        expect(entry.cachedAt, DateTime.utc(2025, 1, 15, 10, 30));
      });

      test('throws on missing sha256', () {
        expect(
          () => CacheEntry.fromJson({
            'sizeBytes': 100,
            'cachedAt': '2025-01-15T10:30:00.000Z',
          }),
          throwsA(isA<TypeError>()),
        );
      });

      test('throws on missing sizeBytes', () {
        expect(
          () => CacheEntry.fromJson({
            'sha256': 'hash',
            'cachedAt': '2025-01-15T10:30:00.000Z',
          }),
          throwsA(isA<TypeError>()),
        );
      });

      test('throws on missing cachedAt', () {
        expect(
          () => CacheEntry.fromJson({
            'sha256': 'hash',
            'sizeBytes': 100,
          }),
          throwsA(isA<TypeError>()),
        );
      });

      test('throws on invalid cachedAt format', () {
        expect(
          () => CacheEntry.fromJson({
            'sha256': 'hash',
            'sizeBytes': 100,
            'cachedAt': 'not-a-date',
          }),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final entry = CacheEntry(
          sha256: 'abc',
          sizeBytes: 512,
          cachedAt: DateTime.utc(2025, 6, 1, 12, 0),
        );
        final json = entry.toJson();

        expect(json['sha256'], 'abc');
        expect(json['sizeBytes'], 512);
        expect(json['cachedAt'], '2025-06-01T12:00:00.000Z');
      });

      test('roundtrips through JSON', () {
        final original = CacheEntry(
          sha256: 'roundtrip_hash',
          sizeBytes: 4096,
          cachedAt: DateTime.utc(2025, 3, 10, 8, 15),
        );

        final roundtripped = CacheEntry.fromJson(original.toJson());

        expect(roundtripped.sha256, original.sha256);
        expect(roundtripped.sizeBytes, original.sizeBytes);
        expect(roundtripped.cachedAt, original.cachedAt);
      });
    });

    group('equality', () {
      test('equal when sha256 and sizeBytes match', () {
        final entry1 = CacheEntry(
          sha256: 'hash1',
          sizeBytes: 100,
          cachedAt: DateTime(2025, 1, 1),
        );
        final entry2 = CacheEntry(
          sha256: 'hash1',
          sizeBytes: 100,
          cachedAt: DateTime(2025, 6, 1),
        );

        expect(entry1, equals(entry2));
        expect(entry1.hashCode, equals(entry2.hashCode));
      });

      test('not equal when sha256 differs', () {
        final entry1 = CacheEntry(
          sha256: 'hash_a',
          sizeBytes: 100,
          cachedAt: DateTime(2025, 1, 1),
        );
        final entry2 = CacheEntry(
          sha256: 'hash_b',
          sizeBytes: 100,
          cachedAt: DateTime(2025, 1, 1),
        );

        expect(entry1, isNot(equals(entry2)));
      });

      test('not equal when sizeBytes differs', () {
        final entry1 = CacheEntry(
          sha256: 'hash',
          sizeBytes: 100,
          cachedAt: DateTime(2025, 1, 1),
        );
        final entry2 = CacheEntry(
          sha256: 'hash',
          sizeBytes: 200,
          cachedAt: DateTime(2025, 1, 1),
        );

        expect(entry1, isNot(equals(entry2)));
      });

      test('identical instances are equal', () {
        final entry = CacheEntry(
          sha256: 'hash',
          sizeBytes: 100,
          cachedAt: DateTime(2025, 1, 1),
        );

        expect(entry, equals(entry));
      });

      test('not equal to different type', () {
        final entry = CacheEntry(
          sha256: 'hash',
          sizeBytes: 100,
          cachedAt: DateTime(2025, 1, 1),
        );
        const Object other = 'not an entry';

        // ignore: unrelated_type_equality_checks
        expect(entry == other, isFalse);
      });
    });

    group('toString', () {
      test('returns formatted string', () {
        final entry = CacheEntry(
          sha256: 'abc123',
          sizeBytes: 2048,
          cachedAt: DateTime.utc(2025, 1, 15),
        );

        final str = entry.toString();
        expect(str, contains('CacheEntry'));
        expect(str, contains('abc123'));
        expect(str, contains('2048'));
      });
    });
  });
}
