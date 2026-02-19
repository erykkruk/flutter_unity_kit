using System.IO;
using System.Security.Cryptography;
using UnityEditor;
using UnityEngine;

namespace UnityKit.Editor
{
    /// <summary>
    /// Editor tool to build raw AssetBundles and generate a
    /// <c>content_manifest.json</c> compatible with <c>unity_kit</c> streaming.
    ///
    /// <para>
    /// Access via the Unity menu: <b>Flutter > Build AssetBundles</b>.
    /// </para>
    ///
    /// <para>
    /// The generated manifest contains a <c>{BASE_URL}</c> placeholder in
    /// bundle URLs. Replace it with the actual CDN URL before uploading.
    /// </para>
    /// </summary>
    public static class AssetBundleManifestBuilder
    {
        private const string OUTPUT_DIR = "Builds/AssetBundles";
        private const string MANIFEST_NAME = "content_manifest.json";
        private const string BASE_URL_PLACEHOLDER = "{BASE_URL}";

        [MenuItem("Flutter/Build AssetBundles")]
        public static void BuildAssetBundles()
        {
            var outputPath = Path.Combine(Application.dataPath, "..", OUTPUT_DIR);

            if (!Directory.Exists(outputPath))
            {
                Directory.CreateDirectory(outputPath);
            }

            var manifest = BuildPipeline.BuildAssetBundles(
                outputPath,
                BuildAssetBundleOptions.None,
                EditorUserBuildSettings.activeBuildTarget
            );

            if (manifest == null)
            {
                Debug.LogError("[UnityKit] AssetBundle build failed.");
                return;
            }

            var bundleNames = manifest.GetAllAssetBundles();
            Debug.Log($"[UnityKit] Built {bundleNames.Length} AssetBundle(s)");

            GenerateManifest(outputPath, bundleNames);
        }

        private static void GenerateManifest(string outputPath, string[] bundleNames)
        {
            var bundlesJson = new System.Text.StringBuilder();
            bundlesJson.Append("[");

            for (var i = 0; i < bundleNames.Length; i++)
            {
                var bundleName = bundleNames[i];
                var bundlePath = Path.Combine(outputPath, bundleName);
                var fileInfo = new FileInfo(bundlePath);

                if (!fileInfo.Exists)
                {
                    Debug.LogWarning($"[UnityKit] Bundle file not found: {bundlePath}");
                    continue;
                }

                var sha256 = ComputeSha256(bundlePath);

                if (i > 0) bundlesJson.Append(",");
                bundlesJson.Append("\n    {");
                bundlesJson.Append($"\n      \"name\": \"{bundleName}\",");
                bundlesJson.Append($"\n      \"url\": \"{BASE_URL_PLACEHOLDER}/{bundleName}\",");
                bundlesJson.Append($"\n      \"sizeBytes\": {fileInfo.Length},");
                bundlesJson.Append($"\n      \"sha256\": \"{sha256}\",");
                bundlesJson.Append("\n      \"isBase\": false,");
                bundlesJson.Append("\n      \"dependencies\": [],");
                bundlesJson.Append($"\n      \"group\": \"default\"");
                bundlesJson.Append("\n    }");
            }

            bundlesJson.Append("\n  ]");

            var manifestJson = "{\n"
                + $"  \"version\": \"1.0.0\",\n"
                + $"  \"baseUrl\": \"{BASE_URL_PLACEHOLDER}\",\n"
                + $"  \"bundles\": {bundlesJson},\n"
                + $"  \"buildTime\": \"{System.DateTime.UtcNow:O}\",\n"
                + $"  \"platform\": \"{EditorUserBuildSettings.activeBuildTarget}\"\n"
                + "}";

            var manifestPath = Path.Combine(outputPath, MANIFEST_NAME);
            File.WriteAllText(manifestPath, manifestJson);

            Debug.Log($"[UnityKit] Manifest generated: {manifestPath}");
            Debug.Log($"[UnityKit] Replace '{BASE_URL_PLACEHOLDER}' in manifest with your CDN URL before uploading.");
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
