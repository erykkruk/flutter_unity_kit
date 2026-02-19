import 'package:flutter_test/flutter_test.dart';
import 'package:unity_kit/src/streaming/models/download_strategy.dart';

void main() {
  group('DownloadStrategy', () {
    test('has all expected values', () {
      expect(DownloadStrategy.values, hasLength(4));
      expect(
        DownloadStrategy.values,
        containsAll([
          DownloadStrategy.wifiOnly,
          DownloadStrategy.wifiOrCellular,
          DownloadStrategy.any,
          DownloadStrategy.manual,
        ]),
      );
    });

    test('enum values have correct names', () {
      expect(DownloadStrategy.wifiOnly.name, 'wifiOnly');
      expect(DownloadStrategy.wifiOrCellular.name, 'wifiOrCellular');
      expect(DownloadStrategy.any.name, 'any');
      expect(DownloadStrategy.manual.name, 'manual');
    });
  });

  group('DownloadStrategyExtension', () {
    group('allowsCellular', () {
      test('wifiOnly does not allow cellular', () {
        expect(DownloadStrategy.wifiOnly.allowsCellular, isFalse);
      });

      test('wifiOrCellular allows cellular', () {
        expect(DownloadStrategy.wifiOrCellular.allowsCellular, isTrue);
      });

      test('any allows cellular', () {
        expect(DownloadStrategy.any.allowsCellular, isTrue);
      });

      test('manual allows cellular', () {
        expect(DownloadStrategy.manual.allowsCellular, isTrue);
      });
    });

    group('allowsAutoDownload', () {
      test('wifiOnly allows auto download', () {
        expect(DownloadStrategy.wifiOnly.allowsAutoDownload, isTrue);
      });

      test('wifiOrCellular allows auto download', () {
        expect(DownloadStrategy.wifiOrCellular.allowsAutoDownload, isTrue);
      });

      test('any allows auto download', () {
        expect(DownloadStrategy.any.allowsAutoDownload, isTrue);
      });

      test('manual does not allow auto download', () {
        expect(DownloadStrategy.manual.allowsAutoDownload, isFalse);
      });
    });

    group('description', () {
      test('wifiOnly has correct description', () {
        expect(DownloadStrategy.wifiOnly.description, 'Wi-Fi only');
      });

      test('wifiOrCellular has correct description', () {
        expect(
          DownloadStrategy.wifiOrCellular.description,
          'Wi-Fi or cellular',
        );
      });

      test('any has correct description', () {
        expect(DownloadStrategy.any.description, 'Any connection');
      });

      test('manual has correct description', () {
        expect(DownloadStrategy.manual.description, 'Manual download only');
      });

      test('all strategies have non-empty descriptions', () {
        for (final strategy in DownloadStrategy.values) {
          expect(strategy.description, isNotEmpty);
        }
      });
    });
  });
}
