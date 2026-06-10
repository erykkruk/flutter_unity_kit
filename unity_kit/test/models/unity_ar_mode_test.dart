import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/models/unity_ar_mode.dart';
import 'package:unity_kit/src/models/unity_config.dart';

void main() {
  group('UnityArMode', () {
    test('isArActive reflects the mode', () {
      expect(UnityArMode.none.isArActive, isFalse);
      expect(UnityArMode.passthrough.isArActive, isTrue);
      expect(UnityArMode.overlay.isArActive, isTrue);
    });

    test('wireName round-trips through fromWireName', () {
      for (final mode in UnityArMode.values) {
        expect(
          UnityArModeExtension.fromWireName(mode.wireName),
          mode,
        );
      }
    });

    test('fromWireName defaults to none for unknown input', () {
      expect(UnityArModeExtension.fromWireName('bogus'), UnityArMode.none);
      expect(UnityArModeExtension.fromWireName(null), UnityArMode.none);
    });
  });

  group('UnityConfig AR', () {
    test('defaults to no AR', () {
      const config = UnityConfig();
      expect(config.arMode, UnityArMode.none);
      expect(config.toCreationParams()['arMode'], 'none');
    });

    test('ar() factory enables overlay with transparency', () {
      final config = UnityConfig.ar();
      expect(config.arMode, UnityArMode.overlay);
      expect(config.transparentBackground, isTrue);
      expect(config.toCreationParams()['arMode'], 'overlay');
    });

    test('ar() factory in passthrough mode is opaque', () {
      final config = UnityConfig.ar(mode: UnityArMode.passthrough);
      expect(config.arMode, UnityArMode.passthrough);
      expect(config.transparentBackground, isFalse);
    });

    test('copyWith preserves and overrides arMode', () {
      const base = UnityConfig(arMode: UnityArMode.passthrough);
      expect(base.copyWith().arMode, UnityArMode.passthrough);
      expect(base.copyWith(arMode: UnityArMode.none).arMode, UnityArMode.none);
    });

    test('toCreationParams carries existing keys', () {
      const config = UnityConfig(targetFrameRate: 30, fullscreen: true);
      final params = config.toCreationParams();
      expect(params['targetFrameRate'], 30);
      expect(params['fullscreen'], isTrue);
      expect(params['platformViewMode'], 'hybridComposition');
    });
  });
}
