/// The state of a single content bundle download.
enum DownloadState {
  /// Queued for download but not yet started.
  queued,

  /// Currently being downloaded.
  downloading,

  /// Download completed successfully.
  completed,

  /// Available from local cache.
  cached,

  /// Download failed.
  failed,

  /// Download was cancelled by the user or system.
  cancelled,
}
