/// Which Unity player runtime the host app ships.
///
/// Unity 6 renamed the Android player class, so the plugin picks the right
/// one by reflection at runtime; this reports what it found.
enum UnityPlayerRuntime {
  /// `com.unity3d.player.UnityPlayerForActivityOrService`, Unity 6 and newer.
  unity6('unity6'),

  /// `com.unity3d.player.UnityPlayer`, Unity 2022.3 LTS and older.
  legacy('legacy'),

  /// The iOS `UnityFramework`.
  unityFramework('unityFramework'),

  /// No Unity runtime is present in this build.
  ///
  /// Expected in a Flutter-only debug build, and the reason a Unity view
  /// would come up blank.
  absent('absent'),

  /// A runtime was found but could not be classified.
  unknown('unknown');

  const UnityPlayerRuntime(this.wireValue);

  /// Value sent over the method channel.
  final String wireValue;

  /// Decodes a runtime from its [wireValue], falling back to [unknown].
  static UnityPlayerRuntime fromWire(String? value) {
    for (final runtime in UnityPlayerRuntime.values) {
      if (runtime.wireValue == value) return runtime;
    }
    return UnityPlayerRuntime.unknown;
  }

  /// Whether a Unity runtime is present at all.
  bool get isPresent => this != absent && this != unknown;
}

/// How a native library measures up against the 16 KB page size requirement.
enum PageAlignmentStatus {
  /// Every loadable segment is aligned to 16 KB or more.
  aligned('aligned'),

  /// At least one library is aligned to less than 16 KB.
  ///
  /// Google Play rejects such an app for updates targeting Android 15
  /// (API 35) and above.
  unaligned('unaligned'),

  /// Alignment could not be determined: no native libraries were found, the
  /// files were unreadable, or the platform does not use ELF at all.
  unknown('unknown');

  const PageAlignmentStatus(this.wireValue);

  /// Value sent over the method channel.
  final String wireValue;

  /// Decodes a status from its [wireValue], falling back to [unknown].
  static PageAlignmentStatus fromWire(String? value) {
    for (final status in PageAlignmentStatus.values) {
      if (status.wireValue == value) return status;
    }
    return PageAlignmentStatus.unknown;
  }
}

/// One native library inspected during the preflight check.
class NativeLibraryReport {
  /// Creates a report for a single shared library.
  const NativeLibraryReport({
    required this.name,
    required this.alignment,
    required this.alignmentBytes,
  });

  /// Decodes a report from the method-channel payload.
  factory NativeLibraryReport.fromMap(Map<Object?, Object?> map) {
    return NativeLibraryReport(
      name: (map['name'] as String?) ?? '',
      alignment: PageAlignmentStatus.fromWire(map['alignment'] as String?),
      alignmentBytes: (map['alignmentBytes'] as num?)?.toInt() ?? 0,
    );
  }

  /// File name, for example `libunity.so`.
  final String name;

  /// Whether this library satisfies the 16 KB requirement.
  final PageAlignmentStatus alignment;

  /// Smallest segment alignment found, in bytes; 0 when unknown.
  final int alignmentBytes;

  @override
  String toString() =>
      'NativeLibraryReport($name, ${alignment.wireValue}, $alignmentBytes B)';
}

/// A preflight report on the Unity runtime the app is actually running with.
///
/// Read it before mounting a [UnityView] to fail loudly instead of showing a
/// blank surface, and to catch the two Unity upgrade traps early:
///
/// - **Unity 6 renamed the Android player class.** [runtime] reports which
///   one was found, so a build that silently shipped without Unity is
///   obvious.
/// - **16 KB page sizes.** Google Play requires every native library in an
///   app targeting Android 15 (API 35) or newer to be aligned to 16 KB.
///   Unity satisfies this from 2022.3.56 and from Unity 6; older Unity
///   builds are rejected at upload. [pageAlignment] reports what the shipped
///   `.so` files actually say, rather than what the Unity version claims.
///
/// ```dart
/// final env = await UnityKitPlatform.instance.environment();
/// if (!env.isReadyForUnity) {
///   debugPrint(env.summary);
/// }
/// ```
class UnityEnvironment {
  /// Creates an environment report.
  const UnityEnvironment({
    required this.runtime,
    required this.playerClassName,
    required this.pageAlignment,
    required this.devicePageSizeBytes,
    required this.abi,
    required this.libraries,
    required this.platformVersion,
  });

  /// Decodes a report from the method-channel payload.
  ///
  /// Missing fields decode to their unknown/empty variants so an older
  /// native side never crashes a newer Dart side.
  factory UnityEnvironment.fromMap(Map<Object?, Object?> map) {
    final rawLibraries = map['libraries'];
    return UnityEnvironment(
      runtime: UnityPlayerRuntime.fromWire(map['runtime'] as String?),
      playerClassName: map['playerClassName'] as String?,
      pageAlignment: PageAlignmentStatus.fromWire(
        map['pageAlignment'] as String?,
      ),
      devicePageSizeBytes: (map['devicePageSizeBytes'] as num?)?.toInt() ?? 0,
      abi: map['abi'] as String?,
      platformVersion: map['platformVersion'] as String?,
      libraries: rawLibraries is List
          ? rawLibraries
              .whereType<Map<Object?, Object?>>()
              .map(NativeLibraryReport.fromMap)
              .toList(growable: false)
          : const <NativeLibraryReport>[],
    );
  }

  /// An empty report, used where no platform implementation answered.
  static const UnityEnvironment unknown = UnityEnvironment(
    runtime: UnityPlayerRuntime.unknown,
    playerClassName: null,
    pageAlignment: PageAlignmentStatus.unknown,
    devicePageSizeBytes: 0,
    abi: null,
    libraries: <NativeLibraryReport>[],
    platformVersion: null,
  );

  /// The Unity runtime found in this build.
  final UnityPlayerRuntime runtime;

  /// Fully qualified class name of the Android player, when one was found.
  final String? playerClassName;

  /// Worst alignment status across [libraries].
  final PageAlignmentStatus pageAlignment;

  /// Page size this device runs with, in bytes; 0 when unknown.
  ///
  /// 16384 on a 16 KB device, 4096 on a classic one. A 4 KB device runs
  /// unaligned libraries fine, which is exactly why this has to be checked
  /// rather than inferred from "it works on my phone".
  final int devicePageSizeBytes;

  /// Primary ABI of the running process, for example `arm64-v8a`.
  final String? abi;

  /// Native libraries inspected, Unity's own first.
  final List<NativeLibraryReport> libraries;

  /// Platform version string, for example the Android release or iOS
  /// system version.
  final String? platformVersion;

  /// Whether a Unity runtime is present and nothing blocks mounting a view.
  bool get isReadyForUnity => runtime.isPresent;

  /// Whether this build would be rejected by Google Play's 16 KB rule.
  ///
  /// Only ever true when a library was actually read and found unaligned;
  /// an undetermined check is not treated as a failure.
  bool get failsPageSizeRequirement =>
      pageAlignment == PageAlignmentStatus.unaligned;

  /// Libraries that are aligned to less than 16 KB.
  List<NativeLibraryReport> get unalignedLibraries => libraries
      .where((library) => library.alignment == PageAlignmentStatus.unaligned)
      .toList(growable: false);

  /// A human-readable summary, meant for logs and debug overlays.
  String get summary {
    final buffer = StringBuffer('Unity runtime: ${runtime.wireValue}');
    if (playerClassName != null) {
      buffer.write(' ($playerClassName)');
    }
    if (abi != null) {
      buffer.write(', abi $abi');
    }
    if (devicePageSizeBytes > 0) {
      buffer.write(', device page size $devicePageSizeBytes B');
    }
    buffer.write(', 16 KB alignment: ${pageAlignment.wireValue}');
    final unaligned = unalignedLibraries;
    if (unaligned.isNotEmpty) {
      buffer.write(
        ' (${unaligned.map((library) => library.name).join(', ')})',
      );
    }
    return buffer.toString();
  }

  @override
  String toString() => 'UnityEnvironment($summary)';
}
