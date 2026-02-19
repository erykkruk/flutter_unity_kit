import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/streaming/models/content_bundle.dart';

void main() {
  group('ContentBundle', () {
    const minimalJson = {
      'name': 'core',
      'url': 'https://cdn.example.com/core.bin',
      'sizeBytes': 1024,
    };

    const fullJson = {
      'name': 'characters',
      'url': 'https://cdn.example.com/characters.bin',
      'sizeBytes': 5242880,
      'sha256': 'abc123def456',
      'isBase': true,
      'dependencies': ['core', 'textures'],
      'group': 'characters',
      'metadata': {'priority': 1},
    };

    test('creates with required fields only', () {
      const bundle = ContentBundle(
        name: 'core',
        url: 'https://cdn.example.com/core.bin',
        sizeBytes: 1024,
      );

      expect(bundle.name, 'core');
      expect(bundle.url, 'https://cdn.example.com/core.bin');
      expect(bundle.sizeBytes, 1024);
      expect(bundle.sha256, isNull);
      expect(bundle.isBase, false);
      expect(bundle.dependencies, isEmpty);
      expect(bundle.group, isNull);
      expect(bundle.metadata, isNull);
    });

    test('creates with all fields', () {
      const bundle = ContentBundle(
        name: 'chars',
        url: 'https://cdn.example.com/chars.bin',
        sizeBytes: 5242880,
        sha256: 'hash123',
        isBase: true,
        dependencies: ['core'],
        group: 'characters',
        metadata: {'priority': 1},
      );

      expect(bundle.sha256, 'hash123');
      expect(bundle.isBase, true);
      expect(bundle.dependencies, ['core']);
      expect(bundle.group, 'characters');
      expect(bundle.metadata, {'priority': 1});
    });

    group('fromJson', () {
      test('parses minimal JSON', () {
        final bundle = ContentBundle.fromJson(minimalJson);

        expect(bundle.name, 'core');
        expect(bundle.url, 'https://cdn.example.com/core.bin');
        expect(bundle.sizeBytes, 1024);
        expect(bundle.isBase, false);
        expect(bundle.dependencies, isEmpty);
      });

      test('parses full JSON', () {
        final bundle = ContentBundle.fromJson(fullJson);

        expect(bundle.name, 'characters');
        expect(bundle.sizeBytes, 5242880);
        expect(bundle.sha256, 'abc123def456');
        expect(bundle.isBase, true);
        expect(bundle.dependencies, ['core', 'textures']);
        expect(bundle.group, 'characters');
        expect(bundle.metadata, {'priority': 1});
      });

      test('throws on missing required fields', () {
        expect(
          () => ContentBundle.fromJson({'name': 'x', 'url': 'y'}),
          throwsA(isA<TypeError>()),
        );
      });
    });

    group('toJson', () {
      test('serializes minimal bundle', () {
        const bundle = ContentBundle(
          name: 'core',
          url: '/core.bin',
          sizeBytes: 1024,
        );
        final json = bundle.toJson();

        expect(json['name'], 'core');
        expect(json['url'], '/core.bin');
        expect(json['sizeBytes'], 1024);
        expect(json['isBase'], false);
        expect(json.containsKey('sha256'), false);
        expect(json.containsKey('dependencies'), false);
        expect(json.containsKey('group'), false);
        expect(json.containsKey('metadata'), false);
      });

      test('serializes full bundle', () {
        const bundle = ContentBundle(
          name: 'chars',
          url: '/chars.bin',
          sizeBytes: 2048,
          sha256: 'hash',
          isBase: true,
          dependencies: ['core'],
          group: 'g1',
          metadata: {'k': 'v'},
        );
        final json = bundle.toJson();

        expect(json['sha256'], 'hash');
        expect(json['isBase'], true);
        expect(json['dependencies'], ['core']);
        expect(json['group'], 'g1');
        expect(json['metadata'], {'k': 'v'});
      });

      test('roundtrips through JSON', () {
        final original = ContentBundle.fromJson(fullJson);
        final roundtripped = ContentBundle.fromJson(original.toJson());

        expect(roundtripped, original);
        expect(roundtripped.name, original.name);
        expect(roundtripped.sizeBytes, original.sizeBytes);
        expect(roundtripped.dependencies, original.dependencies);
      });
    });

    group('formattedSize', () {
      test('formats bytes', () {
        const bundle = ContentBundle(
          name: 'tiny',
          url: '/tiny.bin',
          sizeBytes: 512,
        );

        expect(bundle.formattedSize, '512 B');
      });

      test('formats kilobytes', () {
        const bundle = ContentBundle(
          name: 'small',
          url: '/small.bin',
          sizeBytes: 345 * 1024,
        );

        expect(bundle.formattedSize, '345.0 KB');
      });

      test('formats megabytes', () {
        const bundle = ContentBundle(
          name: 'large',
          url: '/large.bin',
          sizeBytes: 1258291, // ~1.2 MB
        );

        expect(bundle.formattedSize, '1.2 MB');
      });

      test('formats zero bytes', () {
        const bundle = ContentBundle(
          name: 'empty',
          url: '/empty.bin',
          sizeBytes: 0,
        );

        expect(bundle.formattedSize, '0 B');
      });
    });

    group('equality', () {
      test('equal when name and sha256 match', () {
        const a = ContentBundle(
          name: 'core',
          url: '/a.bin',
          sizeBytes: 100,
          sha256: 'hash1',
        );
        const b = ContentBundle(
          name: 'core',
          url: '/b.bin',
          sizeBytes: 200,
          sha256: 'hash1',
        );

        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });

      test('not equal when name differs', () {
        const a = ContentBundle(
          name: 'core',
          url: '/a.bin',
          sizeBytes: 100,
          sha256: 'hash1',
        );
        const b = ContentBundle(
          name: 'other',
          url: '/a.bin',
          sizeBytes: 100,
          sha256: 'hash1',
        );

        expect(a, isNot(b));
      });

      test('not equal when sha256 differs', () {
        const a = ContentBundle(
          name: 'core',
          url: '/a.bin',
          sizeBytes: 100,
          sha256: 'hash1',
        );
        const b = ContentBundle(
          name: 'core',
          url: '/a.bin',
          sizeBytes: 100,
          sha256: 'hash2',
        );

        expect(a, isNot(b));
      });
    });

    test('toString returns readable format', () {
      const bundle = ContentBundle(
        name: 'core',
        url: '/core.bin',
        sizeBytes: 1048576,
        isBase: true,
      );

      expect(bundle.toString(), contains('ContentBundle'));
      expect(bundle.toString(), contains('core'));
      expect(bundle.toString(), contains('1.0 MB'));
      expect(bundle.toString(), contains('true'));
    });
  });
}
