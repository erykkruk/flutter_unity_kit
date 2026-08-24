import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/unity_kit.dart';

void main() {
  group('UnityPlayerRuntime', () {
    test('decodes each wire value', () {
      expect(UnityPlayerRuntime.fromWire('unity6'), UnityPlayerRuntime.unity6);
      expect(UnityPlayerRuntime.fromWire('legacy'), UnityPlayerRuntime.legacy);
      expect(
        UnityPlayerRuntime.fromWire('unityFramework'),
        UnityPlayerRuntime.unityFramework,
      );
      expect(UnityPlayerRuntime.fromWire('absent'), UnityPlayerRuntime.absent);
    });

    test('an unrecognised value decodes to unknown, not an exception', () {
      // A newer native side must never crash an older Dart side.
      expect(
        UnityPlayerRuntime.fromWire('unity7'),
        UnityPlayerRuntime.unknown,
      );
      expect(UnityPlayerRuntime.fromWire(null), UnityPlayerRuntime.unknown);
    });

    test('only a classified runtime counts as present', () {
      expect(UnityPlayerRuntime.unity6.isPresent, isTrue);
      expect(UnityPlayerRuntime.legacy.isPresent, isTrue);
      expect(UnityPlayerRuntime.unityFramework.isPresent, isTrue);
      expect(UnityPlayerRuntime.absent.isPresent, isFalse);
      expect(UnityPlayerRuntime.unknown.isPresent, isFalse);
    });
  });

  group('PageAlignmentStatus', () {
    test('decodes each wire value', () {
      expect(
        PageAlignmentStatus.fromWire('aligned'),
        PageAlignmentStatus.aligned,
      );
      expect(
        PageAlignmentStatus.fromWire('unaligned'),
        PageAlignmentStatus.unaligned,
      );
    });

    test('an unrecognised value decodes to unknown', () {
      expect(
        PageAlignmentStatus.fromWire('mostly'),
        PageAlignmentStatus.unknown,
      );
      expect(PageAlignmentStatus.fromWire(null), PageAlignmentStatus.unknown);
    });
  });

  group('NativeLibraryReport.fromMap', () {
    test('decodes a full payload', () {
      final report = NativeLibraryReport.fromMap(const {
        'name': 'libunity.so',
        'alignment': 'aligned',
        'alignmentBytes': 16384,
      });

      expect(report.name, 'libunity.so');
      expect(report.alignment, PageAlignmentStatus.aligned);
      expect(report.alignmentBytes, 16384);
    });

    test('tolerates a payload with missing fields', () {
      final report = NativeLibraryReport.fromMap(const {});

      expect(report.name, isEmpty);
      expect(report.alignment, PageAlignmentStatus.unknown);
      expect(report.alignmentBytes, 0);
    });
  });

  group('UnityEnvironment.fromMap', () {
    test('decodes a Unity 6 Android report', () {
      final env = UnityEnvironment.fromMap(const {
        'runtime': 'unity6',
        'playerClassName': 'com.unity3d.player.UnityPlayerForActivityOrService',
        'pageAlignment': 'aligned',
        'devicePageSizeBytes': 16384,
        'abi': 'arm64-v8a',
        'platformVersion': '15',
        'libraries': [
          {
            'name': 'libunity.so',
            'alignment': 'aligned',
            'alignmentBytes': 16384
          },
        ],
      });

      expect(env.runtime, UnityPlayerRuntime.unity6);
      expect(
        env.playerClassName,
        'com.unity3d.player.UnityPlayerForActivityOrService',
      );
      expect(env.pageAlignment, PageAlignmentStatus.aligned);
      expect(env.devicePageSizeBytes, 16384);
      expect(env.abi, 'arm64-v8a');
      expect(env.platformVersion, '15');
      expect(env.libraries, hasLength(1));
      expect(env.isReadyForUnity, isTrue);
      expect(env.failsPageSizeRequirement, isFalse);
    });

    test('decodes an iOS report with no libraries', () {
      final env = UnityEnvironment.fromMap(const {
        'runtime': 'unityFramework',
        'playerClassName': 'UnityFramework',
        'pageAlignment': 'unknown',
        'devicePageSizeBytes': 16384,
        'abi': 'arm64',
        'platformVersion': '26.0',
        'libraries': <Object?>[],
      });

      expect(env.runtime, UnityPlayerRuntime.unityFramework);
      expect(env.isReadyForUnity, isTrue);
      expect(env.libraries, isEmpty);
      // No 16 KB requirement applies to iOS, so an unknown alignment must
      // not read as a failure.
      expect(env.failsPageSizeRequirement, isFalse);
    });

    test('an empty payload decodes to the unknown report', () {
      final env = UnityEnvironment.fromMap(const {});

      expect(env.runtime, UnityPlayerRuntime.unknown);
      expect(env.pageAlignment, PageAlignmentStatus.unknown);
      expect(env.devicePageSizeBytes, 0);
      expect(env.libraries, isEmpty);
      expect(env.isReadyForUnity, isFalse);
    });

    test('a malformed libraries entry is skipped, not fatal', () {
      final env = UnityEnvironment.fromMap(const {
        'runtime': 'legacy',
        'libraries': <Object?>[
          'not a map',
          42,
          {
            'name': 'libunity.so',
            'alignment': 'unaligned',
            'alignmentBytes': 4096
          },
        ],
      });

      expect(env.libraries, hasLength(1));
      expect(env.libraries.single.name, 'libunity.so');
    });
  });

  group('UnityEnvironment - page size verdict', () {
    UnityEnvironment withLibraries(List<Map<String, Object?>> libraries) {
      return UnityEnvironment.fromMap({
        'runtime': 'unity6',
        'pageAlignment': libraries.any((l) => l['alignment'] == 'unaligned')
            ? 'unaligned'
            : 'aligned',
        'libraries': libraries,
      });
    }

    test('one unaligned library fails the requirement', () {
      final env = withLibraries([
        {
          'name': 'libunity.so',
          'alignment': 'aligned',
          'alignmentBytes': 16384
        },
        {
          'name': 'libil2cpp.so',
          'alignment': 'unaligned',
          'alignmentBytes': 4096
        },
      ]);

      expect(env.failsPageSizeRequirement, isTrue);
      expect(env.unalignedLibraries.map((l) => l.name), ['libil2cpp.so']);
    });

    test('all-aligned libraries pass', () {
      final env = withLibraries([
        {
          'name': 'libunity.so',
          'alignment': 'aligned',
          'alignmentBytes': 16384
        },
        {'name': 'libmain.so', 'alignment': 'aligned', 'alignmentBytes': 65536},
      ]);

      expect(env.failsPageSizeRequirement, isFalse);
      expect(env.unalignedLibraries, isEmpty);
    });

    test('an undetermined check is not reported as a failure', () {
      // Refusing to answer is not the same as failing; treating it as a
      // failure would cry wolf on every platform without a probe.
      expect(UnityEnvironment.unknown.failsPageSizeRequirement, isFalse);
    });
  });

  group('UnityEnvironment.summary', () {
    test('names the runtime, abi, page size and alignment', () {
      final env = UnityEnvironment.fromMap(const {
        'runtime': 'unity6',
        'playerClassName': 'com.unity3d.player.UnityPlayerForActivityOrService',
        'pageAlignment': 'aligned',
        'devicePageSizeBytes': 16384,
        'abi': 'arm64-v8a',
        'libraries': <Object?>[],
      });

      expect(env.summary, contains('unity6'));
      expect(env.summary, contains('UnityPlayerForActivityOrService'));
      expect(env.summary, contains('arm64-v8a'));
      expect(env.summary, contains('16384'));
      expect(env.summary, contains('aligned'));
    });

    test('lists the offending libraries when the check fails', () {
      final env = UnityEnvironment.fromMap(const {
        'runtime': 'legacy',
        'pageAlignment': 'unaligned',
        'libraries': [
          {
            'name': 'libunity.so',
            'alignment': 'unaligned',
            'alignmentBytes': 4096
          },
        ],
      });

      expect(env.summary, contains('libunity.so'));
      expect(env.summary, contains('unaligned'));
    });

    test('omits fields the probe could not fill in', () {
      expect(UnityEnvironment.unknown.summary, isNot(contains('abi')));
      expect(
        UnityEnvironment.unknown.summary,
        isNot(contains('device page size')),
      );
    });

    test('toString wraps the summary', () {
      expect(UnityEnvironment.unknown.toString(), contains('UnityEnvironment'));
    });
  });
}
