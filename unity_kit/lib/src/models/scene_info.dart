/// Information about a Unity scene.
class SceneInfo {
  /// Creates a new [SceneInfo].
  const SceneInfo({
    required this.name,
    this.buildIndex = -1,
    this.isLoaded = false,
    this.isValid = true,
    this.metadata,
  });

  /// Creates a [SceneInfo] from a map (e.g., from native platform).
  factory SceneInfo.fromMap(Map<String, dynamic> map) {
    return SceneInfo(
      name: map['name'] as String? ?? '',
      buildIndex: map['buildIndex'] as int? ?? -1,
      isLoaded: map['isLoaded'] as bool? ?? false,
      isValid: map['isValid'] as bool? ?? true,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Creates an empty [SceneInfo] representing no scene.
  factory SceneInfo.empty() {
    return const SceneInfo(name: '', isValid: false);
  }

  /// The name of the scene.
  final String name;

  /// The build index of the scene (-1 if unknown).
  final int buildIndex;

  /// Whether the scene is currently loaded.
  final bool isLoaded;

  /// Whether the scene reference is valid.
  final bool isValid;

  /// Optional metadata associated with the scene.
  final Map<String, dynamic>? metadata;

  /// Converts this scene info to a map.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'buildIndex': buildIndex,
      'isLoaded': isLoaded,
      'isValid': isValid,
      if (metadata != null) 'metadata': metadata,
    };
  }

  @override
  String toString() =>
      'SceneInfo(name: $name, buildIndex: $buildIndex, isLoaded: $isLoaded)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SceneInfo &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          buildIndex == other.buildIndex;

  @override
  int get hashCode => name.hashCode ^ buildIndex.hashCode;
}
