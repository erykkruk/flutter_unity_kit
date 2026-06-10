#if UNITY_EDITOR
using System.Collections.Generic;
using System.Text;
using UnityEditor;
using UnityEngine;

namespace UnityKit.Editor
{
    /// <summary>
    /// Editor utility that checks a Unity project for the settings unity_kit
    /// expects before exporting to Flutter. Run it from
    /// <c>Tools ▸ UnityKit ▸ Validate Project</c>.
    ///
    /// Catches the common onboarding mistakes — empty build scene list, wrong
    /// scripting backend, missing ARM64, too-low Android min SDK — and reports
    /// them in one dialog instead of failing late in a device build.
    /// </summary>
    public static class UnityKitProjectValidator
    {
        private const string MenuPath = "Tools/UnityKit/Validate Project";
        private const int AndroidMinSdk = 22;

        [MenuItem(MenuPath)]
        public static void Validate()
        {
            var errors = new List<string>();
            var warnings = new List<string>();

            ValidateScenes(errors, warnings);
            ValidateAndroid(errors, warnings);
            ValidateIos(errors, warnings);

            Report(errors, warnings);
        }

        private static void ValidateScenes(List<string> errors, List<string> warnings)
        {
            var hasEnabledScene = false;
            foreach (var scene in EditorBuildSettings.scenes)
            {
                if (scene.enabled)
                {
                    hasEnabledScene = true;
                    break;
                }
            }

            if (!hasEnabledScene)
            {
                errors.Add("No enabled scenes in Build Settings. Add at least the initial scene.");
            }
        }

        private static void ValidateAndroid(List<string> errors, List<string> warnings)
        {
            if (PlayerSettings.GetScriptingBackend(BuildTargetGroup.Android) != ScriptingImplementation.IL2CPP)
            {
                errors.Add("Android scripting backend must be IL2CPP (Player Settings ▸ Configuration).");
            }

            var arch = PlayerSettings.Android.targetArchitectures;
            if ((arch & AndroidArchitecture.ARM64) == 0)
            {
                errors.Add("Android target architecture must include ARM64.");
            }

            if ((int)PlayerSettings.Android.minSdkVersion < AndroidMinSdk)
            {
                errors.Add($"Android Min SDK must be {AndroidMinSdk}+ (Unity requirement for embedding).");
            }
        }

        private static void ValidateIos(List<string> errors, List<string> warnings)
        {
            if (PlayerSettings.GetScriptingBackend(BuildTargetGroup.iOS) != ScriptingImplementation.IL2CPP)
            {
                warnings.Add("iOS scripting backend is normally IL2CPP for device builds.");
            }
        }

        private static void Report(List<string> errors, List<string> warnings)
        {
            var sb = new StringBuilder();

            if (errors.Count == 0 && warnings.Count == 0)
            {
                sb.Append("UnityKit: project is ready for Flutter export. ✅");
                UnityKitLogger.Info(sb.ToString());
                EditorUtility.DisplayDialog("UnityKit Validation", sb.ToString(), "OK");
                return;
            }

            foreach (var error in errors)
            {
                sb.Append("[x] ").Append(error).Append('\n');
                UnityKitLogger.Error($"Validation: {error}");
            }

            foreach (var warning in warnings)
            {
                sb.Append("[!] ").Append(warning).Append('\n');
                UnityKitLogger.Warning($"Validation: {warning}");
            }

            EditorUtility.DisplayDialog(
                errors.Count > 0 ? "UnityKit Validation — issues found" : "UnityKit Validation — warnings",
                sb.ToString(),
                "OK");
        }
    }
}
#endif
