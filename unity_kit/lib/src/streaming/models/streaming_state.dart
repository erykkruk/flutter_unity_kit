/// The overall state of the streaming subsystem.
enum StreamingState {
  /// Not yet initialized.
  uninitialized,

  /// Currently initializing (fetching manifest, setting up cache).
  initializing,

  /// Ready to download or serve content.
  ready,

  /// Actively downloading one or more bundles.
  downloading,

  /// An unrecoverable error occurred.
  error,
}
