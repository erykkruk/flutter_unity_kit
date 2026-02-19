using System;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using UnityEditor;
using UnityEngine;
using Application = UnityEngine.Application;
using BuildResult = UnityEditor.Build.Reporting.BuildResult;

namespace UnityKit.Editor
{
    /// <summary>
    /// Unity editor build tool for Flutter integration.
    ///
    /// Two export modes:
    ///   1. Standalone (default) — builds to local Builds/ folder.
    ///      Ready to be zipped and uploaded as a CI artifact.
    ///   2. Deploy to Flutter — copies the built artifact into a Flutter project.
    ///      Configurable via Flutter > Settings or UNITY_KIT_FLUTTER_PROJECT env var.
    /// </summary>
    public class Build : EditorWindow
    {
        // ──────────────────────────────────────────────
        // Paths
        // ──────────────────────────────────────────────

        private static readonly string ProjectPath =
            Path.GetFullPath(Path.Combine(Application.dataPath, ".."));

        private static readonly string BuildsPath =
            Path.Combine(ProjectPath, "Builds");

        private static readonly string APKPath =
            Path.Combine(BuildsPath, Application.productName + ".apk");

        // Standalone export targets (inside Unity project)
        private static readonly string AndroidArtifactPath =
            Path.Combine(BuildsPath, "android", "unityLibrary");

        private static readonly string IOSArtifactPath =
            Path.Combine(BuildsPath, "ios", "UnityLibrary");

        private static readonly string WebArtifactPath =
            Path.Combine(BuildsPath, "web", "UnityLibrary");

        // EditorPrefs key for optional Flutter project path
        private const string FLUTTER_PROJECT_PREF = "UnityKit_FlutterProjectPath";

        /// <summary>
        /// Returns the user-configured Flutter project path, or empty string.
        /// Checks environment variable first, then EditorPrefs.
        /// </summary>
        private static string FlutterProjectPath
        {
            get
            {
                // Environment variable takes priority (CI)
                var envPath = Environment.GetEnvironmentVariable("UNITY_KIT_FLUTTER_PROJECT");
                if (!string.IsNullOrEmpty(envPath))
                    return Path.GetFullPath(envPath);

                return EditorPrefs.GetString(FLUTTER_PROJECT_PREF, "");
            }
            set => EditorPrefs.SetString(FLUTTER_PROJECT_PREF, value);
        }

        private static bool HasFlutterProject =>
            !string.IsNullOrEmpty(FlutterProjectPath) && Directory.Exists(FlutterProjectPath);

        // ──────────────────────────────────────────────
        // Menu items — Export (standalone)
        // ──────────────────────────────────────────────

        [MenuItem("Flutter/Export Android (Debug) %&n", false, 101)]
        public static void ExportAndroidDebug()
        {
            DoBuildAndroid(false);
        }

        [MenuItem("Flutter/Export Android (Release) %&m", false, 102)]
        public static void ExportAndroidRelease()
        {
            DoBuildAndroid(true);
        }

        [MenuItem("Flutter/Export iOS (Debug) %&i", false, 201)]
        public static void ExportIOSDebug()
        {
            DoBuildIOS(false);
        }

        [MenuItem("Flutter/Export iOS (Release)", false, 202)]
        public static void ExportIOSRelease()
        {
            DoBuildIOS(true);
        }

        [MenuItem("Flutter/Export WebGL %&w", false, 301)]
        public static void ExportWebGL()
        {
            DoBuildWebGL();
        }

        // ──────────────────────────────────────────────
        // Menu items — Deploy to Flutter (optional)
        // ──────────────────────────────────────────────

        [MenuItem("Flutter/Deploy to Flutter Project", false, 401)]
        public static void DeployToFlutter()
        {
            if (!HasFlutterProject)
            {
                Debug.LogError(
                    "[UnityKit] No Flutter project configured. " +
                    "Set it in Flutter > Settings or via UNITY_KIT_FLUTTER_PROJECT environment variable.");
                return;
            }

            var deployed = false;

            if (Directory.Exists(AndroidArtifactPath))
            {
                var target = Path.Combine(FlutterProjectPath, "android", "unityLibrary");
                Copy(AndroidArtifactPath, target);
                SetupAndroidProject(FlutterProjectPath);
                Debug.Log($"[UnityKit] Deployed Android to: {target}");
                deployed = true;
            }

            if (Directory.Exists(IOSArtifactPath))
            {
                var target = Path.Combine(FlutterProjectPath, "ios", "UnityLibrary");
                Copy(IOSArtifactPath, target);
                Debug.Log($"[UnityKit] Deployed iOS to: {target}");
                deployed = true;
            }

            if (Directory.Exists(WebArtifactPath))
            {
                var target = Path.Combine(FlutterProjectPath, "web", "UnityLibrary");
                Copy(WebArtifactPath, target);
                Debug.Log($"[UnityKit] Deployed WebGL to: {target}");
                deployed = true;
            }

            if (!deployed)
            {
                Debug.LogWarning(
                    "[UnityKit] No build artifacts found. Run an export first (Flutter > Export ...).");
            }
        }

        [MenuItem("Flutter/Deploy to Flutter Project", true)]
        private static bool DeployToFlutterValidate()
        {
            return HasFlutterProject;
        }

        // ──────────────────────────────────────────────
        // Menu items — Settings
        // ──────────────────────────────────────────────

        [MenuItem("Flutter/Settings %&S", false, 501)]
        public static void ShowSettings()
        {
            GetWindow(typeof(Build), false, "Unity Kit Export");
        }

        // ──────────────────────────────────────────────
        // Settings GUI
        // ──────────────────────────────────────────────

        private string _flutterPathField = "";

        private void OnEnable()
        {
            _flutterPathField = FlutterProjectPath;
        }

        private void OnGUI()
        {
            GUILayout.Label("Unity Kit - Export Settings", EditorStyles.boldLabel);
            GUILayout.Space(10);

            // --- Build artifacts ---
            GUILayout.Label("Build Artifacts (standalone)", EditorStyles.boldLabel);
            GUILayout.Label(
                "Exports go to the Builds/ folder inside the Unity project.\n" +
                "Use these as CI artifacts or deploy to a Flutter project.",
                EditorStyles.wordWrappedMiniLabel);
            GUILayout.Space(5);

            EditorGUILayout.LabelField("Android:", AndroidArtifactPath);
            EditorGUILayout.LabelField("iOS:", IOSArtifactPath);
            EditorGUILayout.LabelField("WebGL:", WebArtifactPath);

            GUILayout.Space(5);

            var hasAndroid = Directory.Exists(AndroidArtifactPath);
            var hasIOS = Directory.Exists(IOSArtifactPath);
            var hasWeb = Directory.Exists(WebArtifactPath);
            EditorGUILayout.LabelField("Status:",
                $"Android: {(hasAndroid ? "BUILT" : "—")}  |  " +
                $"iOS: {(hasIOS ? "BUILT" : "—")}  |  " +
                $"WebGL: {(hasWeb ? "BUILT" : "—")}");

            GUILayout.Space(15);

            // --- Flutter project (optional) ---
            GUILayout.Label("Flutter Project (optional)", EditorStyles.boldLabel);
            GUILayout.Label(
                "Set a path to auto-deploy builds into a Flutter project.\n" +
                "Leave empty for standalone mode (CI artifact only).\n" +
                "Can also be set via UNITY_KIT_FLUTTER_PROJECT environment variable.",
                EditorStyles.wordWrappedMiniLabel);
            GUILayout.Space(5);

            EditorGUILayout.BeginHorizontal();
            _flutterPathField = EditorGUILayout.TextField("Path:", _flutterPathField);
            if (GUILayout.Button("Browse", GUILayout.Width(60)))
            {
                var selected = EditorUtility.OpenFolderPanel(
                    "Select Flutter Project Root", _flutterPathField, "");
                if (!string.IsNullOrEmpty(selected))
                    _flutterPathField = selected;
            }
            EditorGUILayout.EndHorizontal();

            if (_flutterPathField != FlutterProjectPath)
            {
                if (GUILayout.Button("Save Flutter Project Path"))
                {
                    FlutterProjectPath = _flutterPathField;
                    Debug.Log($"[UnityKit] Flutter project path saved: {_flutterPathField}");
                }
            }

            if (!string.IsNullOrEmpty(_flutterPathField))
            {
                var pubspec = Path.Combine(_flutterPathField, "pubspec.yaml");
                if (File.Exists(pubspec))
                {
                    EditorGUILayout.HelpBox("Flutter project detected (pubspec.yaml found).", MessageType.Info);
                }
                else if (Directory.Exists(_flutterPathField))
                {
                    EditorGUILayout.HelpBox(
                        "Directory exists but no pubspec.yaml found. Is this a Flutter project?",
                        MessageType.Warning);
                }
                else
                {
                    EditorGUILayout.HelpBox("Directory does not exist.", MessageType.Error);
                }
            }

            GUILayout.Space(20);

            // --- Quick actions ---
            GUILayout.Label("Quick Export", EditorStyles.boldLabel);

            EditorGUILayout.BeginHorizontal();
            if (GUILayout.Button("Android (Debug)", GUILayout.Height(30)))
                ExportAndroidDebug();
            if (GUILayout.Button("Android (Release)", GUILayout.Height(30)))
                ExportAndroidRelease();
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.BeginHorizontal();
            if (GUILayout.Button("iOS (Debug)", GUILayout.Height(30)))
                ExportIOSDebug();
            if (GUILayout.Button("iOS (Release)", GUILayout.Height(30)))
                ExportIOSRelease();
            EditorGUILayout.EndHorizontal();

            if (GUILayout.Button("WebGL", GUILayout.Height(30)))
                ExportWebGL();

            GUILayout.Space(10);

            GUI.enabled = HasFlutterProject && (hasAndroid || hasIOS || hasWeb);
            if (GUILayout.Button("Deploy to Flutter Project", GUILayout.Height(35)))
                DeployToFlutter();
            GUI.enabled = true;

            if (GUILayout.Button("Clean All Builds", GUILayout.Height(25)))
            {
                if (EditorUtility.DisplayDialog(
                        "Clean Builds",
                        "Delete all build artifacts in Builds/ folder?",
                        "Delete", "Cancel"))
                {
                    if (Directory.Exists(BuildsPath))
                        Directory.Delete(BuildsPath, true);
                    Debug.Log("[UnityKit] Build artifacts cleaned.");
                }
            }
        }

        // ──────────────────────────────────────────────
        // Android Build
        // ──────────────────────────────────────────────

        private static void DoBuildAndroid(bool isReleaseBuild)
        {
            EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android, BuildTarget.Android);

            if (Directory.Exists(APKPath))
                Directory.Delete(APKPath, true);

            if (Directory.Exists(AndroidArtifactPath))
                Directory.Delete(AndroidArtifactPath, true);

            EditorUserBuildSettings.androidBuildSystem = AndroidBuildSystem.Gradle;
            EditorUserBuildSettings.exportAsGoogleAndroidProject = true;

            var playerOptions = new BuildPlayerOptions
            {
                scenes = GetEnabledScenes(),
                target = BuildTarget.Android,
                locationPathName = APKPath,
            };

            if (!isReleaseBuild)
            {
                playerOptions.options = BuildOptions.AllowDebugging | BuildOptions.Development;
            }

            // IL2CPP compiler configuration
#if UNITY_2022_1_OR_NEWER
            PlayerSettings.SetIl2CppCompilerConfiguration(BuildTargetGroup.Android,
                isReleaseBuild ? Il2CppCompilerConfiguration.Release : Il2CppCompilerConfiguration.Debug);
#endif

#if UNITY_ANDROID && UNITY_6000_0_OR_NEWER
            UnityEditor.Android.UserBuildSettings.DebugSymbols.level = isReleaseBuild
                ? Unity.Android.Types.DebugSymbolLevel.None
                : Unity.Android.Types.DebugSymbolLevel.SymbolTable;
            UnityEditor.Android.UserBuildSettings.DebugSymbols.format =
                Unity.Android.Types.DebugSymbolFormat.LegacyExtensions;
#endif

#if UNITY_ANDROID && UNITY_2023_1_OR_NEWER
            PlayerSettings.Android.applicationEntry = AndroidApplicationEntry.Activity;
#endif

            EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android, BuildTarget.Android);

            var report = BuildPipeline.BuildPlayer(playerOptions);

            if (report.summary.result != BuildResult.Succeeded)
                throw new Exception("Android build failed");

            // Copy unityLibrary to artifact path
            var buildPath = Path.Combine(APKPath, "unityLibrary");
            Copy(buildPath, AndroidArtifactPath);

            // Unity 6 shared folder
            var sharedPath = Path.Combine(APKPath, "shared");
            if (Directory.Exists(sharedPath))
            {
                Copy(sharedPath, Path.Combine(AndroidArtifactPath, "shared"));
            }

            // Post-process: convert to library module
            ModifyAndroidGradle(AndroidArtifactPath);

            // Copy launcher resources
            Copy(
                Path.Combine(APKPath, "launcher/src/main/res"),
                Path.Combine(AndroidArtifactPath, "src/main/res"),
                false
            );

            var mode = isReleaseBuild ? "Release" : "Debug";
            Debug.Log($"-- Android {mode} Build: SUCCESSFUL --");
            Debug.Log($"[UnityKit] Artifact: {AndroidArtifactPath}");

            // Auto-deploy if Flutter project is configured
            if (HasFlutterProject)
            {
                var target = Path.Combine(FlutterProjectPath, "android", "unityLibrary");
                Copy(AndroidArtifactPath, target);
                SetupAndroidProject(FlutterProjectPath);
                Debug.Log($"[UnityKit] Auto-deployed to: {target}");
            }
        }

        private static void ModifyAndroidGradle(string artifactPath)
        {
            // --- build.gradle ---
            var buildFile = Path.Combine(artifactPath, "build.gradle");
            var buildText = File.ReadAllText(buildFile);

            // Convert from application to library
            buildText = buildText.Replace("com.android.application", "com.android.library");
            buildText = buildText.Replace("bundle {", "splits {");
            buildText = buildText.Replace("enableSplit = false", "enable false");
            buildText = buildText.Replace("enableSplit = true", "enable true");
            buildText = buildText.Replace(
                "implementation fileTree(dir: 'libs', include: ['*.jar'])",
                "implementation(name: 'unity-classes', ext:'jar')");
            buildText = buildText.Replace(" + unityStreamingAssets.tokenize(', ')", "");

            // Disable Unity NDK path (conflicts with Flutter)
            buildText = buildText.Replace("ndkPath \"", "// ndkPath \"");

            // Unity 6: fix shared/ path
            buildText = Regex.Replace(buildText, @"\.\./shared/", "./shared/");

            // Add namespace for Android Gradle Plugin 8+
            if (!buildText.Contains("namespace"))
            {
                buildText = buildText.Replace("compileOptions {",
                    "if (project.android.hasProperty(\"namespace\")) {\n        namespace 'com.unity3d.player'\n    }\n\n    compileOptions {");
            }

            // Remove applicationId
            buildText = Regex.Replace(buildText, @"\n.*applicationId '.+'.*\n", "\n");
            File.WriteAllText(buildFile, buildText);

            // --- AndroidManifest.xml ---
            var manifestFile = Path.Combine(artifactPath, "src/main/AndroidManifest.xml");
            var manifestText = File.ReadAllText(manifestFile);

            // Strip application attributes and activity block
            manifestText = Regex.Replace(manifestText, @"<application .*>", "<application>");
            manifestText = new Regex(@"<activity.*>(\s|\S)+?</activity>", RegexOptions.Multiline)
                .Replace(manifestText, "");
            File.WriteAllText(manifestFile, manifestText);

            // --- proguard-unity.txt ---
            var proguardFile = Path.Combine(artifactPath, "proguard-unity.txt");
            if (File.Exists(proguardFile))
            {
                var proguardText = File.ReadAllText(proguardFile);
                proguardText = proguardText.Replace("-ignorewarnings",
                    "-keep class com.unity_kit.** { *; }\n-keep class com.unity3d.player.** { *; }\n-ignorewarnings");
                File.WriteAllText(proguardFile, proguardText);
            }

            // --- strings.xml ---
            var stringsFile = Path.Combine(APKPath, "launcher", "src", "main", "res", "values", "strings.xml");
            if (File.Exists(stringsFile))
            {
                var stringsText = File.ReadAllText(stringsFile);
                if (!stringsText.Contains("game_view_content_description"))
                {
                    stringsText = stringsText.Replace("<resources>",
                        "<resources>\n  <string name=\"game_view_content_description\">Game view</string>");
                    File.WriteAllText(stringsFile, stringsText);
                }
            }
        }

        /// <summary>
        /// Patches the Flutter project's gradle files to include unityLibrary.
        /// Called during deploy, NOT during standalone export.
        /// </summary>
        private static void SetupAndroidProject(string flutterProjectPath)
        {
            var androidPath = Path.Combine(flutterProjectPath, "android");
            var androidAppPath = Path.Combine(androidPath, "app");

            if (!Directory.Exists(androidPath))
            {
                Debug.LogWarning($"[UnityKit] Flutter android/ folder not found at: {androidPath}");
                return;
            }

            // Detect Kotlin DSL (Flutter 3.29+)
            if (File.Exists(Path.Combine(androidPath, "build.gradle.kts")))
            {
                SetupAndroidProjectKotlin(androidPath, androidAppPath);
                return;
            }

            SetupAndroidProjectGroovy(androidPath, androidAppPath);
        }

        private static void SetupAndroidProjectGroovy(string androidPath, string androidAppPath)
        {
            var projBuildPath = Path.Combine(androidPath, "build.gradle");
            var settingsPath = Path.Combine(androidPath, "settings.gradle");
            var appBuildPath = Path.Combine(androidAppPath, "build.gradle");

            if (!File.Exists(projBuildPath) || !File.Exists(settingsPath)) return;

            var projBuildScript = File.ReadAllText(projBuildPath);
            var settingsScript = File.ReadAllText(settingsPath);

            // Add flatDir repository
            if (!Regex.IsMatch(projBuildScript, @"flatDir[^/]*[^}]*}"))
            {
                projBuildScript = new Regex(@"allprojects \{[^\{]*\{", RegexOptions.Multiline)
                    .Replace(projBuildScript, "allprojects {\n    repositories {\n        flatDir {\n            dirs \"${project(':unityLibrary').projectDir}/libs\"\n        }\n");
                File.WriteAllText(projBuildPath, projBuildScript);
            }

            // Add include :unityLibrary
            if (!settingsScript.Contains(":unityLibrary"))
            {
                settingsScript += "\ninclude \":unityLibrary\"\nproject(\":unityLibrary\").projectDir = file(\"./unityLibrary\")\n";
                File.WriteAllText(settingsPath, settingsScript);
            }

            // Add dependency
            if (File.Exists(appBuildPath))
            {
                var appBuildScript = File.ReadAllText(appBuildPath);
                if (!appBuildScript.Contains("implementation project(':unityLibrary')"))
                {
                    if (Regex.IsMatch(appBuildScript, @"dependencies \{"))
                    {
                        appBuildScript = new Regex(@"dependencies \{", RegexOptions.Multiline)
                            .Replace(appBuildScript, "dependencies {\n    implementation project(':unityLibrary')\n");
                    }
                    else
                    {
                        appBuildScript += "\ndependencies {\n    implementation project(':unityLibrary')\n}\n";
                    }
                    File.WriteAllText(appBuildPath, appBuildScript);
                }
            }
        }

        private static void SetupAndroidProjectKotlin(string androidPath, string androidAppPath)
        {
            var projBuildPath = Path.Combine(androidPath, "build.gradle.kts");
            var settingsPath = Path.Combine(androidPath, "settings.gradle.kts");
            var appBuildPath = Path.Combine(androidAppPath, "build.gradle.kts");

            if (!File.Exists(projBuildPath) || !File.Exists(settingsPath)) return;

            var projBuildScript = File.ReadAllText(projBuildPath);
            var settingsScript = File.ReadAllText(settingsPath);

            // Add flatDir repository
            if (!Regex.IsMatch(projBuildScript, @"flatDir[^/]*[^}]*}"))
            {
                projBuildScript = new Regex(@"allprojects \{[^\{]*\{", RegexOptions.Multiline)
                    .Replace(projBuildScript, "allprojects {\n    repositories {\n        flatDir {\n            dirs(file(\"${project(\":unityLibrary\").projectDir}/libs\"))\n        }\n");
                File.WriteAllText(projBuildPath, projBuildScript);
            }

            // Add include :unityLibrary
            if (!settingsScript.Contains(":unityLibrary"))
            {
                settingsScript += "\ninclude(\":unityLibrary\")\nproject(\":unityLibrary\").projectDir = file(\"./unityLibrary\")\n";
                File.WriteAllText(settingsPath, settingsScript);
            }

            // Add dependency
            if (File.Exists(appBuildPath))
            {
                var appBuildScript = File.ReadAllText(appBuildPath);
                if (!appBuildScript.Contains(":unityLibrary"))
                {
                    if (Regex.IsMatch(appBuildScript, @"dependencies \{"))
                    {
                        appBuildScript = new Regex(@"dependencies \{", RegexOptions.Multiline)
                            .Replace(appBuildScript, "dependencies {\n    implementation(project(\":unityLibrary\"))\n");
                    }
                    else
                    {
                        appBuildScript += "\ndependencies {\n    implementation(project(\":unityLibrary\"))\n}\n";
                    }
                    File.WriteAllText(appBuildPath, appBuildScript);
                }
            }
        }

        // ──────────────────────────────────────────────
        // iOS Build
        // ──────────────────────────────────────────────

        private static void DoBuildIOS(bool isReleaseBuild)
        {
            bool abortBuild = false;

#if !UNITY_IOS
            abortBuild = true;
            if (Application.isBatchMode)
            {
                Debug.LogError("Incorrect iOS build target. Use -buildTarget iOS.");
            }
            else
            {
                bool dialogResult = EditorUtility.DisplayDialog(
                    "Switch build target to iOS?",
                    "Exporting to iOS first requires a build target switch.\nClick 'Export iOS' again after importing finishes.",
                    "Switch to iOS",
                    "Cancel");
                if (dialogResult)
                {
                    EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.iOS, BuildTarget.iOS);
                }
            }
#endif
            if (abortBuild)
                return;

            if (Directory.Exists(IOSArtifactPath))
                Directory.Delete(IOSArtifactPath, true);

#if UNITY_2021_1_OR_NEWER
            EditorUserBuildSettings.iOSXcodeBuildConfig = XcodeBuildConfig.Release;
#else
            EditorUserBuildSettings.iOSBuildConfigType = iOSBuildType.Release;
#endif

            // IL2CPP compiler configuration
#if UNITY_2022_1_OR_NEWER
            PlayerSettings.SetIl2CppCompilerConfiguration(BuildTargetGroup.iOS,
                isReleaseBuild ? Il2CppCompilerConfiguration.Release : Il2CppCompilerConfiguration.Debug);
#endif

            var playerOptions = new BuildPlayerOptions
            {
                scenes = GetEnabledScenes(),
                target = BuildTarget.iOS,
                locationPathName = IOSArtifactPath,
            };

            if (!isReleaseBuild)
            {
                playerOptions.options = BuildOptions.AllowDebugging | BuildOptions.Development;
            }

            var report = BuildPipeline.BuildPlayer(playerOptions);

            if (report.summary.result != BuildResult.Succeeded)
                throw new Exception("iOS build failed");

            // Post-process Xcode project
            bool postBuildExecuted = false;
#if UNITY_IOS
            XCodePostBuild.PostBuild(BuildTarget.iOS, report.summary.outputPath);
            postBuildExecuted = true;
#endif

            if (postBuildExecuted)
            {
                var mode = isReleaseBuild ? "Release" : "Debug";
                Debug.Log($"-- iOS {mode} Build: SUCCESSFUL --");
                Debug.Log($"[UnityKit] Artifact: {IOSArtifactPath}");

                // Auto-deploy if Flutter project is configured
                if (HasFlutterProject)
                {
                    var target = Path.Combine(FlutterProjectPath, "ios", "UnityLibrary");
                    Copy(IOSArtifactPath, target);
                    Debug.Log($"[UnityKit] Auto-deployed to: {target}");
                }
            }
            else
            {
                Debug.LogError("iOS export failed. Failed to modify Unity's Xcode project.");
            }
        }

        // ──────────────────────────────────────────────
        // WebGL Build
        // ──────────────────────────────────────────────

        private static void DoBuildWebGL()
        {
            EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.WebGL, BuildTarget.WebGL);

            if (Directory.Exists(WebArtifactPath))
                Directory.Delete(WebArtifactPath, true);

            var playerOptions = new BuildPlayerOptions
            {
                scenes = GetEnabledScenes(),
                target = BuildTarget.WebGL,
                locationPathName = WebArtifactPath,
            };

            var report = BuildPipeline.BuildPlayer(playerOptions);

            if (report.summary.result != BuildResult.Succeeded)
                throw new Exception("WebGL build failed");

            ModifyWebGLExport(WebArtifactPath);

            Debug.Log("-- WebGL Build: SUCCESSFUL --");
            Debug.Log($"[UnityKit] Artifact: {WebArtifactPath}");

            // Auto-deploy if Flutter project is configured
            if (HasFlutterProject)
            {
                var target = Path.Combine(FlutterProjectPath, "web", "UnityLibrary");
                Copy(WebArtifactPath, target);
                Debug.Log($"[UnityKit] Auto-deployed to: {target}");
            }
        }

        private static void ModifyWebGLExport(string artifactPath)
        {
            // Inject Flutter bridge into index.html
            var indexFile = Path.Combine(artifactPath, "index.html");
            var indexHtml = File.ReadAllText(indexFile);

            indexHtml = indexHtml.Replace("<script>", @"
    <script>
        var mainUnityInstance;

        window['handleUnityMessage'] = function (params) {
            window.parent.postMessage({
                name: 'onUnityMessage',
                data: params,
            }, '*');
        };

        window['handleUnitySceneLoaded'] = function (name, buildIndex, isLoaded, isValid) {
            window.parent.postMessage({
                name: 'onUnitySceneLoaded',
                data: {
                    'name': name,
                    'buildIndex': buildIndex,
                    'isLoaded': isLoaded == 1,
                    'isValid': isValid == 1,
                }
            }, '*');
        };

        window.parent.addEventListener('unityFlutterBiding', function (args) {
            const obj = JSON.parse(args.data);
            mainUnityInstance.SendMessage(obj.gameObject, obj.methodName, obj.message);
        });

        window.parent.addEventListener('unityFlutterBidingFnCal', function (args) {
            mainUnityInstance.SendMessage('FlutterBridge', 'ReceiveMessage', args.data);
        });
        ");

            // Full-screen canvas
            indexHtml = indexHtml.Replace("canvas.style.width = \"960px\";", "canvas.style.width = \"100%\";");
            indexHtml = indexHtml.Replace("canvas.style.height = \"600px\";", "canvas.style.height = \"100%\";");

            // Capture Unity instance
            indexHtml = indexHtml.Replace("}).then((unityInstance) => {", @"
         }).then((unityInstance) => {
           window.parent.postMessage('unityReady', '*');
           mainUnityInstance = unityInstance;
         ");
            File.WriteAllText(indexFile, indexHtml);

            // Full-screen CSS
            var cssFile = Path.Combine(artifactPath, "TemplateData", "style.css");
            if (File.Exists(cssFile))
            {
                File.WriteAllText(cssFile, @"
body { padding: 0; margin: 0; overflow: hidden; }
#unity-container { position: absolute }
#unity-container.unity-desktop { width: 100%; height: 100% }
#unity-container.unity-mobile { width: 100%; height: 100% }
#unity-canvas { background: #231F20 }
.unity-mobile #unity-canvas { width: 100%; height: 100% }
#unity-loading-bar { position: absolute; left: 50%; top: 50%; transform: translate(-50%, -50%); display: none }
#unity-footer { display: none }
.unity-mobile #unity-footer { display: none }
");
            }
        }

        // ──────────────────────────────────────────────
        // Utilities
        // ──────────────────────────────────────────────

        private static void Copy(string source, string destinationPath, bool clearDestination = true)
        {
            if (clearDestination && Directory.Exists(destinationPath))
                Directory.Delete(destinationPath, true);

            Directory.CreateDirectory(destinationPath);

            foreach (var dirPath in Directory.GetDirectories(source, "*", SearchOption.AllDirectories))
                Directory.CreateDirectory(dirPath.Replace(source, destinationPath));

            foreach (var newPath in Directory.GetFiles(source, "*.*", SearchOption.AllDirectories))
                File.Copy(newPath, newPath.Replace(source, destinationPath), true);
        }

        private static string[] GetEnabledScenes()
        {
            return EditorBuildSettings.scenes
                .Where(s => s.enabled)
                .Select(s => s.path)
                .ToArray();
        }
    }
}
