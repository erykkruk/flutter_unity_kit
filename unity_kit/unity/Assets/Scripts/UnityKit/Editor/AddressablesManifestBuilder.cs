#if ADDRESSABLES_INSTALLED
using System.IO;
using System.Security.Cryptography;
using UnityEditor;
using UnityEditor.AddressableAssets;
using UnityEditor.AddressableAssets.Build;
using UnityEditor.AddressableAssets.Settings;
using UnityEngine;

namespace UnityKit.Editor
{
    /// <summary>
    /// Editor tool to build Addressables content and generate a
    /// <c>content_manifest.json</c> compatible with <c>unity_kit</c> streaming.
    ///
    /// <para>
    /// Access via the Unity menu: <b>Flutter > Build Addressables</b>.
    /// Requires the <c>com.unity.addressables</c> package and the
    /// <c>ADDRESSABLES_INSTALLED</c> scripting define symbol.
    /// </para>
    /// </summary>
    public static class AddressablesManifestBuilder
    {
        private const string MANIFEST_NAME = "content_manifest.json";

        [MenuItem("Flutter/Build Addressables")]
        public static void BuildAddressables()
        {
            var settings = AddressableAssetSettingsDefaultObject.Settings;
            if (settings == null)
            {
                Debug.LogError("[UnityKit] Addressable Asset Settings not found. Configure Addressables first.");
                return;
            }

            AddressableAssetSettings.CleanPlayerContent(
                AddressableAssetSettingsDefaultObject.Settings.ActivePlayerDataBuilder
            );

            AddressableAssetSettings.BuildPlayerContent(out AddressablesPlayerBuildResult result);

            if (!string.IsNullOrEmpty(result.Error))
            {
                Debug.LogError($"[UnityKit] Addressables build failed: {result.Error}");
                return;
            }

            Debug.Log($"[UnityKit] Addressables built successfully. Output: {settings.RemoteCatalogBuildPath.GetValue(settings)}");

            GenerateManifest(settings, result);
        }

        private static void GenerateManifest(AddressableAssetSettings settings, AddressablesPlayerBuildResult result)
        {
            var remoteBuildPath = settings.RemoteCatalogBuildPath.GetValue(settings);
            var remoteLoadPath = settings.RemoteCatalogLoadPath.GetValue(settings);

            if (!Directory.Exists(remoteBuildPath))
            {
                Debug.LogWarning($"[UnityKit] Remote build path does not exist: {remoteBuildPath}");
                return;
            }

            var bundleFiles = Directory.GetFiles(remoteBuildPath, "*.bundle");
            var bundlesJson = new System.Text.StringBuilder();
            bundlesJson.Append("[");

            for (var i = 0; i < bundleFiles.Length; i++)
            {
                var bundlePath = bundleFiles[i];
                var bundleName = Path.GetFileName(bundlePath);
                var fileInfo = new FileInfo(bundlePath);
                var sha256 = ComputeSha256(bundlePath);

                if (i > 0) bundlesJson.Append(",");
                bundlesJson.Append("\n    {");
                bundlesJson.Append($"\n      \"name\": \"{bundleName}\",");
                bundlesJson.Append($"\n      \"url\": \"{remoteLoadPath}/{bundleName}\",");
                bundlesJson.Append($"\n      \"sizeBytes\": {fileInfo.Length},");
                bundlesJson.Append($"\n      \"sha256\": \"{sha256}\",");
                bundlesJson.Append("\n      \"isBase\": false,");
                bundlesJson.Append("\n      \"dependencies\": [],");
                bundlesJson.Append($"\n      \"group\": \"addressables\"");
                bundlesJson.Append("\n    }");
            }

            bundlesJson.Append("\n  ]");

            var manifestJson = "{\n"
                + $"  \"version\": \"1.0.0\",\n"
                + $"  \"baseUrl\": \"{remoteLoadPath}\",\n"
                + $"  \"bundles\": {bundlesJson},\n"
                + $"  \"buildTime\": \"{System.DateTime.UtcNow:O}\",\n"
                + $"  \"platform\": \"{EditorUserBuildSettings.activeBuildTarget}\"\n"
                + "}";

            var manifestPath = Path.Combine(remoteBuildPath, MANIFEST_NAME);
            File.WriteAllText(manifestPath, manifestJson);

            Debug.Log($"[UnityKit] Addressables manifest generated: {manifestPath}");
        }

        private static string ComputeSha256(string filePath)
        {
            using (var sha256 = SHA256.Create())
            using (var stream = File.OpenRead(filePath))
            {
                var hash = sha256.ComputeHash(stream);
                return System.BitConverter.ToString(hash).Replace("-", "").ToLowerInvariant();
            }
        }
    }
}
#endif
