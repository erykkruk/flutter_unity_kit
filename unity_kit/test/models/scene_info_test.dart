import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/models/scene_info.dart';

void main() {
  group('SceneInfo', () {
    group('constructor', () {
      test('creates instance with required name', () {
        const scene = SceneInfo(name: 'TestScene');

        expect(scene.name, 'TestScene');
        expect(scene.buildIndex, -1);
        expect(scene.isLoaded, isFalse);
        expect(scene.isValid, isTrue);
        expect(scene.metadata, isNull);
      });

      test('creates instance with all parameters', () {
        const metadata = {'key': 'value'};
        const scene = SceneInfo(
          name: 'Level1',
          buildIndex: 2,
          isLoaded: true,
          isValid: true,
          metadata: metadata,
        );

        expect(scene.name, 'Level1');
        expect(scene.buildIndex, 2);
        expect(scene.isLoaded, isTrue);
        expect(scene.isValid, isTrue);
        expect(scene.metadata, metadata);
      });
    });

    group('fromMap', () {
      test('creates instance from complete map', () {
        final map = {
          'name': 'GameScene',
          'buildIndex': 3,
          'isLoaded': true,
          'isValid': true,
          'metadata': {'level': 5},
        };

        final scene = SceneInfo.fromMap(map);

        expect(scene.name, 'GameScene');
        expect(scene.buildIndex, 3);
        expect(scene.isLoaded, isTrue);
        expect(scene.isValid, isTrue);
        expect(scene.metadata, {'level': 5});
      });

      test('uses defaults for missing map values', () {
        final scene = SceneInfo.fromMap(<String, dynamic>{});

        expect(scene.name, '');
        expect(scene.buildIndex, -1);
        expect(scene.isLoaded, isFalse);
        expect(scene.isValid, isTrue);
        expect(scene.metadata, isNull);
      });

      test('handles partial map', () {
        final scene = SceneInfo.fromMap({'name': 'PartialScene'});

        expect(scene.name, 'PartialScene');
        expect(scene.buildIndex, -1);
        expect(scene.isLoaded, isFalse);
        expect(scene.isValid, isTrue);
        expect(scene.metadata, isNull);
      });

      test('handles null name in map', () {
        final scene = SceneInfo.fromMap({'name': null});

        expect(scene.name, '');
      });
    });

    group('empty', () {
      test('creates an empty scene info', () {
        final scene = SceneInfo.empty();

        expect(scene.name, '');
        expect(scene.isValid, isFalse);
        expect(scene.buildIndex, -1);
        expect(scene.isLoaded, isFalse);
        expect(scene.metadata, isNull);
      });
    });

    group('toMap', () {
      test('converts to map without metadata', () {
        const scene = SceneInfo(
          name: 'TestScene',
          buildIndex: 1,
          isLoaded: true,
          isValid: true,
        );

        final map = scene.toMap();

        expect(map['name'], 'TestScene');
        expect(map['buildIndex'], 1);
        expect(map['isLoaded'], isTrue);
        expect(map['isValid'], isTrue);
        expect(map.containsKey('metadata'), isFalse);
      });

      test('converts to map with metadata', () {
        const scene = SceneInfo(
          name: 'TestScene',
          metadata: {'difficulty': 'hard'},
        );

        final map = scene.toMap();

        expect(map['metadata'], {'difficulty': 'hard'});
      });

      test('roundtrips through fromMap and toMap', () {
        const original = SceneInfo(
          name: 'RoundTrip',
          buildIndex: 5,
          isLoaded: true,
          isValid: true,
          metadata: {'key': 'value'},
        );

        final recreated = SceneInfo.fromMap(original.toMap());

        expect(recreated.name, original.name);
        expect(recreated.buildIndex, original.buildIndex);
        expect(recreated.isLoaded, original.isLoaded);
        expect(recreated.isValid, original.isValid);
        expect(recreated.metadata, original.metadata);
      });
    });

    group('equality', () {
      test('equal when same name and buildIndex', () {
        const scene1 = SceneInfo(name: 'Scene', buildIndex: 1);
        const scene2 = SceneInfo(name: 'Scene', buildIndex: 1);

        expect(scene1, equals(scene2));
      });

      test('equal even with different isLoaded', () {
        const scene1 = SceneInfo(name: 'Scene', buildIndex: 1, isLoaded: true);
        const scene2 = SceneInfo(name: 'Scene', buildIndex: 1, isLoaded: false);

        expect(scene1, equals(scene2));
      });

      test('not equal when different name', () {
        const scene1 = SceneInfo(name: 'Scene1', buildIndex: 1);
        const scene2 = SceneInfo(name: 'Scene2', buildIndex: 1);

        expect(scene1, isNot(equals(scene2)));
      });

      test('not equal when different buildIndex', () {
        const scene1 = SceneInfo(name: 'Scene', buildIndex: 1);
        const scene2 = SceneInfo(name: 'Scene', buildIndex: 2);

        expect(scene1, isNot(equals(scene2)));
      });

      test('identical instances are equal', () {
        const scene = SceneInfo(name: 'Scene');

        expect(scene, equals(scene));
      });

      test('not equal to different type', () {
        const scene = SceneInfo(name: 'Scene');
        const Object other = 'Scene';

        // ignore: unrelated_type_equality_checks
        expect(scene == other, isFalse);
      });
    });

    group('hashCode', () {
      test('same for equal instances', () {
        const scene1 = SceneInfo(name: 'Scene', buildIndex: 1);
        const scene2 = SceneInfo(name: 'Scene', buildIndex: 1);

        expect(scene1.hashCode, equals(scene2.hashCode));
      });

      test('different for different instances', () {
        const scene1 = SceneInfo(name: 'Scene1', buildIndex: 1);
        const scene2 = SceneInfo(name: 'Scene2', buildIndex: 2);

        expect(scene1.hashCode, isNot(equals(scene2.hashCode)));
      });
    });

    group('toString', () {
      test('returns formatted string', () {
        const scene = SceneInfo(
          name: 'TestScene',
          buildIndex: 3,
          isLoaded: true,
        );

        expect(
          scene.toString(),
          'SceneInfo(name: TestScene, buildIndex: 3, isLoaded: true)',
        );
      });

      test('returns formatted string for default values', () {
        const scene = SceneInfo(name: 'Empty');

        expect(
          scene.toString(),
          'SceneInfo(name: Empty, buildIndex: -1, isLoaded: false)',
        );
      });
    });
  });
}
