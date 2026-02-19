/// Strategy that controls when automatic downloads are allowed.
enum DownloadStrategy {
  /// Download only over Wi-Fi connections.
  wifiOnly,

  /// Download over Wi-Fi or cellular connections.
  wifiOrCellular,

  /// Download over any available connection.
  any,

  /// Never auto-download; user must trigger downloads manually.
  manual,
}

/// Convenience getters for [DownloadStrategy].
extension DownloadStrategyExtension on DownloadStrategy {
  /// Whether this strategy permits downloading over cellular data.
  bool get allowsCellular => this != DownloadStrategy.wifiOnly;

  /// Whether this strategy permits automatic (non-user-triggered) downloads.
  bool get allowsAutoDownload => this != DownloadStrategy.manual;

  /// Human-readable description of the strategy.
  String get description => switch (this) {
        DownloadStrategy.wifiOnly => 'Wi-Fi only',
        DownloadStrategy.wifiOrCellular => 'Wi-Fi or cellular',
        DownloadStrategy.any => 'Any connection',
        DownloadStrategy.manual => 'Manual download only',
      };
}
