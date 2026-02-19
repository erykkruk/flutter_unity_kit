import 'download_state.dart';

/// Tracks the download progress of a single content bundle.
///
/// Example:
/// ```dart
/// final progress = DownloadProgress.starting('characters', 5242880);
/// debugPrint(progress.percentageString); // "0%"
/// ```
class DownloadProgress {
  /// Creates a new [DownloadProgress].
  const DownloadProgress({
    required this.bundleName,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.state,
    this.error,
    this.bytesPerSecond = 0,
    this.estimatedSecondsRemaining = 0,
  });

  /// Creates a progress snapshot for a download that just started.
  factory DownloadProgress.starting(String bundleName, int totalBytes) {
    return DownloadProgress(
      bundleName: bundleName,
      downloadedBytes: 0,
      totalBytes: totalBytes,
      state: DownloadState.downloading,
    );
  }

  /// Creates a progress snapshot for a completed download.
  factory DownloadProgress.completed(String bundleName, int totalBytes) {
    return DownloadProgress(
      bundleName: bundleName,
      downloadedBytes: totalBytes,
      totalBytes: totalBytes,
      state: DownloadState.completed,
    );
  }

  /// Creates a progress snapshot for content served from cache.
  factory DownloadProgress.cached(String bundleName, int totalBytes) {
    return DownloadProgress(
      bundleName: bundleName,
      downloadedBytes: totalBytes,
      totalBytes: totalBytes,
      state: DownloadState.cached,
    );
  }

  /// Creates a progress snapshot for a failed download.
  factory DownloadProgress.failed(String bundleName, {String? error}) {
    return DownloadProgress(
      bundleName: bundleName,
      downloadedBytes: 0,
      totalBytes: 0,
      state: DownloadState.failed,
      error: error,
    );
  }

  /// Name of the bundle being downloaded.
  final String bundleName;

  /// Number of bytes downloaded so far.
  final int downloadedBytes;

  /// Total size of the bundle in bytes.
  final int totalBytes;

  /// Current download state.
  final DownloadState state;

  /// Error message if the download failed.
  final String? error;

  /// Current download speed in bytes per second.
  final int bytesPerSecond;

  /// Estimated time remaining in seconds.
  final int estimatedSecondsRemaining;

  /// Download progress as a fraction from 0.0 to 1.0.
  double get percentage =>
      totalBytes > 0 ? (downloadedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  /// Download progress as a human-readable string (e.g., "75%").
  String get percentageString => '${(percentage * 100).round()}%';

  /// Whether the download has completed successfully.
  bool get isComplete => state == DownloadState.completed;

  /// Whether the download has failed.
  bool get isFailed => state == DownloadState.failed;

  /// Whether the download is actively transferring data.
  bool get isInProgress => state == DownloadState.downloading;

  /// Current download speed as a human-readable string (e.g., "1.2 MB/s").
  String get speedString {
    const megabyte = 1024 * 1024;
    const kilobyte = 1024;

    if (bytesPerSecond >= megabyte) {
      final mbps = bytesPerSecond / megabyte;
      return '${mbps.toStringAsFixed(1)} MB/s';
    } else if (bytesPerSecond >= kilobyte) {
      final kbps = bytesPerSecond / kilobyte;
      return '${kbps.toStringAsFixed(1)} KB/s';
    }
    return '$bytesPerSecond B/s';
  }

  /// Estimated time remaining as a human-readable string (e.g., "2m 30s").
  String get etaString {
    if (estimatedSecondsRemaining <= 0) return '0s';

    final minutes = estimatedSecondsRemaining ~/ 60;
    final seconds = estimatedSecondsRemaining % 60;

    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  @override
  String toString() =>
      'DownloadProgress($bundleName: $percentageString, state: $state)';
}
