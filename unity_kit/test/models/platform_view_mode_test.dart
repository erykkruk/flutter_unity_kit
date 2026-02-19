import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/models/platform_view_mode.dart';

void main() {
  group('PlatformViewMode', () {
    test('has all expected values', () {
      expect(PlatformViewMode.values, hasLength(3));
      expect(
        PlatformViewMode.values,
        containsAll([
          PlatformViewMode.hybridComposition,
          PlatformViewMode.virtualDisplay,
          PlatformViewMode.textureLayer,
        ]),
      );
    });
  });

  group('PlatformViewModeExtension', () {
    group('description', () {
      test('hybridComposition has correct description', () {
        expect(
          PlatformViewMode.hybridComposition.description,
          'Hybrid Composition (default, best compatibility)',
        );
      });

      test('virtualDisplay has correct description', () {
        expect(
          PlatformViewMode.virtualDisplay.description,
          'Virtual Display (better performance)',
        );
      });

      test('textureLayer has correct description', () {
        expect(
          PlatformViewMode.textureLayer.description,
          'Texture Layer (best performance, limited support)',
        );
      });

      test('all modes have non-empty descriptions', () {
        for (final mode in PlatformViewMode.values) {
          expect(mode.description, isNotEmpty);
        }
      });
    });

    group('isDefault', () {
      test('hybridComposition is the default', () {
        expect(PlatformViewMode.hybridComposition.isDefault, isTrue);
      });

      test('virtualDisplay is not the default', () {
        expect(PlatformViewMode.virtualDisplay.isDefault, isFalse);
      });

      test('textureLayer is not the default', () {
        expect(PlatformViewMode.textureLayer.isDefault, isFalse);
      });

      test('only one mode is the default', () {
        final defaultCount =
            PlatformViewMode.values.where((mode) => mode.isDefault).length;
        expect(defaultCount, 1);
      });
    });
  });
}
