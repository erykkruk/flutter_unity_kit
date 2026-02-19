import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/streaming/models/content_bundle.dart';
import 'package:unity_kit/src/streaming/models/content_manifest.dart';

void main() {
  group('ContentManifest', () {
    final sampleJson = {
      'version': '1.0.0',
      'baseUrl': 'https://cdn.example.com/bundles',
      'bundles': [
        {
          'name': 'core',
          'url': '/core.bin',
          'sizeBytes': 1024,
          'isBase': true,
          'group': 'base',
        },
        {
          'name': 'textures',
          'url': '/textures.bin',
          'sizeBytes': 2048,
          'isBase': true,
          'dependencies': ['core'],
          'group': 'base',
        },
        {
          'name': 'characters',
          'url': '/characters.bin',
          'sizeBytes': 4096,
          'dependencies': ['core', 'textures'],
          'group': 'characters',
        },
        {
          'name': 'levels',
          'url': '/levels.bin',
          'sizeBytes': 8192,
          'group': 'levels',
        },
      ],
      'metadata': {'env': 'production'},
      'buildTime': '2025-01-15T10:30:00.000Z',
      'platform': 'android',
    };

    group('fromJson', () {
      test('parses minimal manifest', () {
        final manifest = ContentManifest.fromJson({
          'version': '1.0.0',
          'baseUrl': 'https://cdn.example.com',
          'bundles': <Map<String, dynamic>>[],
        });

        expect(manifest.version, '1.0.0');
        expect(manifest.baseUrl, 'https://cdn.example.com');
        expect(manifest.bundles, isEmpty);
        expect(manifest.metadata, isNull);
        expect(manifest.buildTime, isNull);
        expect(manifest.platform, isNull);
      });

      test('parses full manifest', () {
        final manifest = ContentManifest.fromJson(sampleJson);

        expect(manifest.version, '1.0.0');
        expect(manifest.baseUrl, 'https://cdn.example.com/bundles');
        expect(manifest.bundles, hasLength(4));
        expect(manifest.metadata, {'env': 'production'});
        expect(manifest.buildTime, DateTime.utc(2025, 1, 15, 10, 30));
        expect(manifest.platform, 'android');
      });

      test('parses bundle details correctly', () {
        final manifest = ContentManifest.fromJson(sampleJson);
        final core = manifest.bundles.first;

        expect(core.name, 'core');
        expect(core.isBase, true);
        expect(core.sizeBytes, 1024);
      });
    });

    group('toJson', () {
      test('roundtrips through JSON', () {
        final original = ContentManifest.fromJson(sampleJson);
        final json = original.toJson();
        final roundtripped = ContentManifest.fromJson(json);

        expect(roundtripped.version, original.version);
        expect(roundtripped.baseUrl, original.baseUrl);
        expect(roundtripped.bundleCount, original.bundleCount);
        expect(roundtripped.platform, original.platform);
      });

      test('omits null optional fields', () {
        const manifest = ContentManifest(
          version: '1.0.0',
          baseUrl: 'https://cdn.example.com',
          bundles: [],
        );
        final json = manifest.toJson();

        expect(json.containsKey('metadata'), false);
        expect(json.containsKey('buildTime'), false);
        expect(json.containsKey('platform'), false);
      });
    });

    group('baseBundles', () {
      test('returns only base bundles', () {
        final manifest = ContentManifest.fromJson(sampleJson);
        final base = manifest.baseBundles;

        expect(base, hasLength(2));
        expect(base.every((b) => b.isBase), true);
        expect(base.map((b) => b.name), containsAll(['core', 'textures']));
      });

      test('returns empty list when no base bundles', () {
        final manifest = ContentManifest.fromJson({
          'version': '1.0.0',
          'baseUrl': 'https://cdn.example.com',
          'bundles': [
            {'name': 'a', 'url': '/a.bin', 'sizeBytes': 100},
          ],
        });

        expect(manifest.baseBundles, isEmpty);
      });
    });

    group('streamingBundles', () {
      test('returns only non-base bundles', () {
        final manifest = ContentManifest.fromJson(sampleJson);
        final streaming = manifest.streamingBundles;

        expect(streaming, hasLength(2));
        expect(streaming.every((b) => !b.isBase), true);
        expect(
          streaming.map((b) => b.name),
          containsAll(['characters', 'levels']),
        );
      });
    });

    group('totalSize', () {
      test('sums all bundle sizes', () {
        final manifest = ContentManifest.fromJson(sampleJson);

        expect(manifest.totalSize, 1024 + 2048 + 4096 + 8192);
      });

      test('returns zero for empty manifest', () {
        const manifest = ContentManifest(
          version: '1.0.0',
          baseUrl: 'https://cdn.example.com',
          bundles: [],
        );

        expect(manifest.totalSize, 0);
      });
    });

    group('bundleCount', () {
      test('returns number of bundles', () {
        final manifest = ContentManifest.fromJson(sampleJson);

        expect(manifest.bundleCount, 4);
      });
    });

    group('getBundlesByGroup', () {
      test('returns bundles in group', () {
        final manifest = ContentManifest.fromJson(sampleJson);
        final base = manifest.getBundlesByGroup('base');

        expect(base, hasLength(2));
        expect(base.map((b) => b.name), containsAll(['core', 'textures']));
      });

      test('returns empty list for unknown group', () {
        final manifest = ContentManifest.fromJson(sampleJson);

        expect(manifest.getBundlesByGroup('unknown'), isEmpty);
      });
    });

    group('getBundleByName', () {
      test('finds existing bundle', () {
        final manifest = ContentManifest.fromJson(sampleJson);
        final bundle = manifest.getBundleByName('characters');

        expect(bundle, isNotNull);
        expect(bundle!.name, 'characters');
        expect(bundle.sizeBytes, 4096);
      });

      test('returns null for unknown name', () {
        final manifest = ContentManifest.fromJson(sampleJson);

        expect(manifest.getBundleByName('nonexistent'), isNull);
      });
    });

    group('resolveDependencies', () {
      test('resolves direct dependencies', () {
        final manifest = ContentManifest.fromJson(sampleJson);
        final deps = manifest.resolveDependencies('textures');

        expect(deps, hasLength(1));
        expect(deps.first.name, 'core');
      });

      test('resolves transitive dependencies in order', () {
        final manifest = ContentManifest.fromJson(sampleJson);
        final deps = manifest.resolveDependencies('characters');

        expect(deps, hasLength(2));
        expect(deps[0].name, 'core');
        expect(deps[1].name, 'textures');
      });

      test('returns empty list for bundle without dependencies', () {
        final manifest = ContentManifest.fromJson(sampleJson);
        final deps = manifest.resolveDependencies('core');

        expect(deps, isEmpty);
      });

      test('returns empty list for unknown bundle', () {
        final manifest = ContentManifest.fromJson(sampleJson);
        final deps = manifest.resolveDependencies('nonexistent');

        expect(deps, isEmpty);
      });

      test('throws on circular dependency', () {
        const manifest = ContentManifest(
          version: '1.0.0',
          baseUrl: 'https://cdn.example.com',
          bundles: [
            ContentBundle(
              name: 'a',
              url: '/a.bin',
              sizeBytes: 100,
              dependencies: ['b'],
            ),
            ContentBundle(
              name: 'b',
              url: '/b.bin',
              sizeBytes: 100,
              dependencies: ['a'],
            ),
          ],
        );

        expect(
          () => manifest.resolveDependencies('a'),
          throwsA(isA<StateError>()),
        );
      });
    });

    test('toString returns readable format', () {
      final manifest = ContentManifest.fromJson(sampleJson);

      expect(manifest.toString(), contains('ContentManifest'));
      expect(manifest.toString(), contains('1.0.0'));
      expect(manifest.toString(), contains('4'));
    });
  });
}
