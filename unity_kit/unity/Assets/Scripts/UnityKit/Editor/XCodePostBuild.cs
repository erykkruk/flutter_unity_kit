#if UNITY_IOS

using System;
using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;
using UnityEditor;
using UnityEditor.iOS.Xcode;

namespace UnityKit.Editor
{
    /// <summary>
    /// iOS post-build processor for unity_kit Flutter integration.
    ///
    /// Patches the exported Unity Xcode project to:
    /// 1. Post "UnityReady" notification (required by unity_kit iOS plugin)
    /// 2. Set SKIP_INSTALL = YES (framework build)
    /// 3. Disable bitcode
    /// 4. Add Data folder reference
    ///
    /// NOTE: Unlike flutter_unity_widget, unity_kit uses @_cdecl functions in
    /// its Swift plugin for message bridging. We do NOT inject OnUnityMessage/
    /// OnUnitySceneLoaded C functions here — those are handled by
    /// FlutterBridgeRegistry.swift via @_cdecl("SendMessageToFlutter") and
    /// @_cdecl("SendSceneLoadedToFlutter").
    /// </summary>
    public static class XCodePostBuild
    {
        private const string TouchedMarker = "https://github.com/aspect-build/unity-kit";

        public static void PostBuild(BuildTarget target, string pathToBuiltProject)
        {
            if (target != BuildTarget.iOS) return;

            PatchUnityNativeCode(pathToBuiltProject);
            UpdateUnityProjectFiles(pathToBuiltProject);
            UpdateBuildSettings(pathToBuiltProject);
        }

        private static void UpdateBuildSettings(string pathToBuildProject)
        {
            var pbx = new PBXProject();
            var pbxPath = Path.Combine(pathToBuildProject, "Unity-iPhone.xcodeproj/project.pbxproj");
            pbx.ReadFromFile(pbxPath);

            var targetGuid = pbx.GetUnityFrameworkTargetGuid();
            var projGuid = pbx.ProjectGuid();

            pbx.SetBuildProperty(targetGuid, "SKIP_INSTALL", "YES");
            pbx.SetBuildProperty(projGuid, "ENABLE_BITCODE", "NO");

            pbx.WriteToFile(pbxPath);
        }

        private static void UpdateUnityProjectFiles(string pathToBuiltProject)
        {
            var pbx = new PBXProject();
            var pbxPath = Path.Combine(pathToBuiltProject, "Unity-iPhone.xcodeproj/project.pbxproj");
            pbx.ReadFromFile(pbxPath);

            var targetGuid = pbx.TargetGuidByName("UnityFramework");
            var fileGuid = pbx.AddFolderReference(Path.Combine(pathToBuiltProject, "Data"), "Data");
            pbx.AddFileToBuild(targetGuid, fileGuid);

            pbx.WriteToFile(pbxPath);
        }

        private static void PatchUnityNativeCode(string pathToBuiltProject)
        {
            var mmPath = Path.Combine(pathToBuiltProject, "Classes/UnityAppController.mm");

            // Only patch: add UnityReady notification to startUnity:
            if (!CheckTouched(mmPath))
            {
                EditUnityAppControllerMM(mmPath);
                MarkTouched(mmPath, "#include <sys/sysctl.h>");
            }
        }

        /// <summary>
        /// Patches UnityAppController.mm to post "UnityReady" NSNotification
        /// at the end of startUnity:. The unity_kit iOS plugin observes this
        /// notification to know when Unity is ready to receive messages.
        /// </summary>
        private static void EditUnityAppControllerMM(string path)
        {
            var inScope = false;
            var markerDetected = false;

            EditCodeFile(path, line =>
            {
                // Inject UnityReady notification at end of startUnity:
                inScope |= line.Contains("- (void)startUnity:");
                markerDetected |= inScope && line.Contains(TouchedMarker);

                if (inScope && Regex.Match(line, @"^}(\s)*$").Success)
                {
                    inScope = false;
                    if (markerDetected)
                    {
                        return new[] { line };
                    }
                    return new[]
                    {
                        "    // Modified by " + TouchedMarker,
                        @"    [[NSNotificationCenter defaultCenter] postNotificationName: @""UnityReady"" object:self];",
                        "}",
                    };
                }

                return new[] { line };
            });
        }

        private static bool CheckTouched(string path)
        {
            var touched = false;
            EditCodeFile(path, line =>
            {
                touched |= line.Contains("// Edited by " + TouchedMarker)
                    || line.Contains("// Added by " + TouchedMarker)
                    || line.Contains("// Modified by " + TouchedMarker);
                return new[] { line };
            });
            return touched;
        }

        private static void MarkTouched(string path, string detection)
        {
            var inScope = false;
            EditCodeFile(path, line =>
            {
                inScope |= line.Contains(detection);
                if (inScope && line.Trim() == "")
                {
                    inScope = false;
                    return new[] { "", "// Edited by " + TouchedMarker, "" };
                }
                return new[] { line };
            });
        }

        private static void EditCodeFile(string path, Func<string, IEnumerable<string>> lineHandler)
        {
            var bakPath = path + ".bak";
            if (File.Exists(bakPath)) File.Delete(bakPath);
            File.Move(path, bakPath);

            using (var reader = File.OpenText(bakPath))
            using (var stream = File.Create(path))
            using (var writer = new StreamWriter(stream))
            {
                string line;
                while ((line = reader.ReadLine()) != null)
                {
                    foreach (var o in lineHandler(line))
                        writer.WriteLine(o);
                }
            }
        }
    }
}

#endif
