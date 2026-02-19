/// A single downloadable content bundle within a [ContentManifest].
///
/// Example:
/// ```dart
/// const bundle = ContentBundle(
///   name: 'characters_base',
///   url: 'https://cdn.example.com/bundles/characters_base.bin',
///   sizeBytes: 5242880,
///   sha256: 'abc123',
///   isBase: true,
/// );
/// ```
class ContentBundle {
  /// Creates a new [ContentBundle].
  const ContentBundle({
    required this.name,
    required this.url,
    required this.sizeBytes,
    this.sha256,
    this.isBase = false,
    this.dependencies = const [],
    this.group,
    this.metadata,
  });

  /// Parses a [ContentBundle] from a JSON map.
  factory ContentBundle.fromJson(Map<String, dynamic> json) {
    return ContentBundle(
      name: json['name'] as String,
      url: json['url'] as String,
      sizeBytes: json['sizeBytes'] as int,
      sha256: json['sha256'] as String?,
      isBase: json['isBase'] as bool? ?? false,
      dependencies:
          (json['dependencies'] as List<Object?>?)?.cast<String>().toList() ??
              const [],
      group: json['group'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Unique name identifying this bundle within the manifest.
  final String name;

  /// Remote URL to download the bundle from.
  final String url;

  /// Size of the bundle in bytes.
  final int sizeBytes;

  /// SHA-256 hash of the bundle content for integrity verification.
  final String? sha256;

  /// Whether this is a base bundle that must be downloaded before streaming.
  final bool isBase;

  /// Names of other bundles that must be downloaded before this one.
  final List<String> dependencies;

  /// Optional group label for categorization (e.g., 'characters', 'levels').
  final String? group;

  /// Arbitrary metadata attached to this bundle.
  final Map<String, dynamic>? metadata;

  /// Human-readable file size (e.g., "1.2 MB", "345 KB", "512 B").
  String get formattedSize {
    const megabyte = 1024 * 1024;
    const kilobyte = 1024;

    if (sizeBytes >= megabyte) {
      final mb = sizeBytes / megabyte;
      return '${mb.toStringAsFixed(1)} MB';
    } else if (sizeBytes >= kilobyte) {
      final kb = sizeBytes / kilobyte;
      return '${kb.toStringAsFixed(1)} KB';
    }
    return '$sizeBytes B';
  }

  /// Serializes this bundle to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'sizeBytes': sizeBytes,
      if (sha256 != null) 'sha256': sha256,
      'isBase': isBase,
      if (dependencies.isNotEmpty) 'dependencies': dependencies,
      if (group != null) 'group': group,
      if (metadata != null) 'metadata': metadata,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContentBundle &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          sha256 == other.sha256;

  @override
  int get hashCode => name.hashCode ^ sha256.hashCode;

  @override
  String toString() =>
      'ContentBundle(name: $name, size: $formattedSize, isBase: $isBase)';
}
