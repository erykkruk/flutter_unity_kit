using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace UnityKit
{
    // -----------------------------------------------------------------------
    // Request / Response DTOs for AssetBundle communication
    // -----------------------------------------------------------------------

    /// <summary>
    /// Request to load an AssetBundle and optionally extract an asset.
    /// </summary>
    [Serializable]
    public class LoadBundleRequest
    {
        public string bundleName;
        public string callbackId;
        /// <summary>Optional asset name within the bundle. If empty, loads the bundle only.</summary>
        public string assetName;
    }

    /// <summary>
    /// Request to load a scene from a cached AssetBundle.
    /// </summary>
    [Serializable]
    public class LoadBundleSceneRequest
    {
        public string bundleName;
        public string callbackId;
        /// <summary>"Single" or "Additive".</summary>
        public string loadMode;
    }

    /// <summary>
    /// Request to unload an AssetBundle.
    /// </summary>
    [Serializable]
    public class UnloadBundleRequest
    {
        public string bundleName;
    }

    /// <summary>
    /// Response sent to Flutter after a bundle load completes.
    /// </summary>
    [Serializable]
    public class BundleLoadedResponse
    {
        public string callbackId;
        public string bundleName;
        public bool success;
        public string error;
    }

    // -----------------------------------------------------------------------
    // FlutterAssetBundleManager
    // -----------------------------------------------------------------------

    /// <summary>
    /// Manages raw AssetBundle loading for Flutter asset streaming.
    ///
    /// <para>
    /// Receives cache paths from Flutter and loads bundles / scenes from local
    /// files using <c>AssetBundle.LoadFromFileAsync</c>. Registers itself with
    /// <see cref="MessageRouter"/> under the target name
    /// <c>"FlutterAssetBundleManager"</c>.
    /// </para>
    ///
    /// <para>
    /// Unlike <see cref="FlutterAddressablesManager"/>, this manager does not
    /// require the Addressables package. It tracks loaded bundles in a
    /// dictionary for explicit unloading.
    /// </para>
    ///
    /// <para>
    /// <b>Supported messages:</b>
    /// <list type="bullet">
    ///   <item><c>SetCachePath</c>  - configure the local cache directory</item>
    ///   <item><c>LoadBundle</c>    - load an AssetBundle and optionally extract an asset</item>
    ///   <item><c>LoadScene</c>     - load a scene from a cached bundle</item>
    ///   <item><c>UnloadBundle</c>  - unload a previously loaded AssetBundle</item>
    /// </list>
    /// </para>
    /// </summary>
    public class FlutterAssetBundleManager : MonoBehaviour
    {
        // -------------------------------------------------------------------
        // Singleton
        // -------------------------------------------------------------------

        /// <summary>Singleton instance.</summary>
        public static FlutterAssetBundleManager Instance { get; private set; }

        // -------------------------------------------------------------------
        // Constants
        // -------------------------------------------------------------------

        private const string TARGET_NAME = "FlutterAssetBundleManager";
        private const string LOG_PREFIX = "[UnityKit] FlutterAssetBundleManager";

        private const string METHOD_SET_CACHE_PATH = "SetCachePath";
        private const string METHOD_LOAD_BUNDLE = "LoadBundle";
        private const string METHOD_LOAD_SCENE = "LoadScene";
        private const string METHOD_UNLOAD_BUNDLE = "UnloadBundle";

        private const string STATUS_LOADING = "loading";
        private const string STATUS_LOADING_SCENE = "loading_scene";
        private const string ERROR_NOT_INITIALIZED = "FlutterAssetBundleManager not initialized. Call SetCachePath first.";

        private const string LOAD_MODE_ADDITIVE = "Additive";

        // -------------------------------------------------------------------
        // State
        // -------------------------------------------------------------------

        private string _cachePath;
        private bool _isInitialized;

        /// <summary>Tracks loaded AssetBundles for explicit unloading.</summary>
        private readonly Dictionary<string, AssetBundle> _loadedBundles = new Dictionary<string, AssetBundle>();

        /// <summary>Whether the manager has been initialised with a cache path.</summary>
        public bool IsInitialized => _isInitialized;

        /// <summary>Number of currently loaded AssetBundles.</summary>
        public int LoadedBundleCount => _loadedBundles.Count;

        // -------------------------------------------------------------------
        // Lifecycle
        // -------------------------------------------------------------------

        private void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }

            Instance = this;
            DontDestroyOnLoad(gameObject);
        }

        private void OnEnable()
        {
            MessageRouter.Register(TARGET_NAME, HandleMessage);
        }

        private void OnDisable()
        {
            MessageRouter.Unregister(TARGET_NAME);
        }

        private void OnDestroy()
        {
            // Unload all tracked bundles on destruction.
            foreach (var kvp in _loadedBundles)
            {
                if (kvp.Value != null)
                {
                    kvp.Value.Unload(true);
                }
            }
            _loadedBundles.Clear();

            if (Instance == this)
            {
                Instance = null;
            }
        }

        // -------------------------------------------------------------------
        // Message handling
        // -------------------------------------------------------------------

        private void HandleMessage(string method, string data)
        {
            switch (method)
            {
                case METHOD_SET_CACHE_PATH:
                    SetCachePath(data);
                    break;

                case METHOD_LOAD_BUNDLE:
                    HandleLoadBundle(data);
                    break;

                case METHOD_LOAD_SCENE:
                    HandleLoadScene(data);
                    break;

                case METHOD_UNLOAD_BUNDLE:
                    HandleUnloadBundle(data);
                    break;

                default:
                    Debug.LogWarning($"{LOG_PREFIX}: Unknown method '{method}'");
                    break;
            }
        }

        private void HandleLoadBundle(string data)
        {
            var request = JsonUtility.FromJson<LoadBundleRequest>(data);
            if (request == null)
            {
                Debug.LogError($"{LOG_PREFIX}: Failed to parse LoadBundleRequest");
                return;
            }

            if (!_isInitialized)
            {
                SendError(request.callbackId, ERROR_NOT_INITIALIZED, "not_initialized");
                return;
            }

            StartCoroutine(LoadBundleCoroutine(request.bundleName, request.callbackId, request.assetName));
        }

        private void HandleLoadScene(string data)
        {
            var request = JsonUtility.FromJson<LoadBundleSceneRequest>(data);
            if (request == null)
            {
                Debug.LogError($"{LOG_PREFIX}: Failed to parse LoadBundleSceneRequest");
                return;
            }

            if (!_isInitialized)
            {
                SendError(request.callbackId, ERROR_NOT_INITIALIZED, "not_initialized");
                return;
            }

            StartCoroutine(LoadSceneCoroutine(request.bundleName, request.callbackId, request.loadMode));
        }

        private void HandleUnloadBundle(string data)
        {
            var request = JsonUtility.FromJson<UnloadBundleRequest>(data);
            if (request == null)
            {
                Debug.LogError($"{LOG_PREFIX}: Failed to parse UnloadBundleRequest");
                return;
            }

            UnloadBundle(request.bundleName);
        }

        // -------------------------------------------------------------------
        // Cache path configuration
        // -------------------------------------------------------------------

        /// <summary>
        /// Set the local cache directory used to resolve bundle file paths.
        /// Must be called before any load operations.
        /// </summary>
        public void SetCachePath(string path)
        {
            if (string.IsNullOrEmpty(path))
            {
                Debug.LogError($"{LOG_PREFIX}: Cache path cannot be null or empty");
                return;
            }

            var normalized = System.IO.Path.GetFullPath(path);
            _cachePath = normalized;
            _isInitialized = true;
            Debug.Log($"{LOG_PREFIX}: Cache path set");
        }

        // -------------------------------------------------------------------
        // Load bundle
        // -------------------------------------------------------------------

        /// <summary>
        /// Returns a safe bundle file path within the cache directory.
        /// Strips directory separators from the bundle name to prevent path traversal.
        /// </summary>
        private string SafeBundlePath(string bundleName)
        {
            var sanitized = System.IO.Path.GetFileName(bundleName);
            var fullPath = System.IO.Path.GetFullPath(System.IO.Path.Combine(_cachePath, sanitized));

            // Verify the resolved path is still within the cache directory.
            if (!fullPath.StartsWith(_cachePath, StringComparison.Ordinal))
            {
                return null;
            }
            return fullPath;
        }

        private IEnumerator LoadBundleCoroutine(string bundleName, string callbackId, string assetName)
        {
            // Check if already loaded.
            if (_loadedBundles.TryGetValue(bundleName, out var existingBundle) && existingBundle != null)
            {
                Debug.Log($"{LOG_PREFIX}: Bundle '{bundleName}' already loaded");
                SendBundleLoaded(callbackId, bundleName, true);
                yield break;
            }

            var bundlePath = SafeBundlePath(bundleName);
            if (bundlePath == null)
            {
                SendError(callbackId, $"Invalid bundle name: {bundleName}", "invalid_name");
                yield break;
            }

            if (!System.IO.File.Exists(bundlePath))
            {
                SendError(callbackId, $"Bundle file not found: {bundlePath}", "file_not_found");
                yield break;
            }

            var loadRequest = AssetBundle.LoadFromFileAsync(bundlePath);

            while (!loadRequest.isDone)
            {
                SendProgress(callbackId, loadRequest.progress, STATUS_LOADING);
                yield return null;
            }

            var bundle = loadRequest.assetBundle;

            if (bundle == null)
            {
                SendError(callbackId, $"Failed to load AssetBundle: {bundleName}", "load_failed");
                yield break;
            }

            _loadedBundles[bundleName] = bundle;
            Debug.Log($"{LOG_PREFIX}: Loaded bundle '{bundleName}'");

            // Optionally load a specific asset from the bundle.
            if (!string.IsNullOrEmpty(assetName))
            {
                var assetRequest = bundle.LoadAssetAsync<GameObject>(assetName);

                while (!assetRequest.isDone)
                {
                    SendProgress(callbackId, assetRequest.progress, STATUS_LOADING);
                    yield return null;
                }

                if (assetRequest.asset == null)
                {
                    SendError(callbackId, $"Asset '{assetName}' not found in bundle '{bundleName}'", "asset_not_found");
                    yield break;
                }

                Debug.Log($"{LOG_PREFIX}: Loaded asset '{assetName}' from bundle '{bundleName}'");
            }

            SendBundleLoaded(callbackId, bundleName, true);
        }

        // -------------------------------------------------------------------
        // Load scene
        // -------------------------------------------------------------------

        private IEnumerator LoadSceneCoroutine(string bundleName, string callbackId, string loadMode)
        {
            // Ensure the bundle is loaded first.
            if (!_loadedBundles.ContainsKey(bundleName))
            {
                var bundlePath = SafeBundlePath(bundleName);
                if (bundlePath == null)
                {
                    SendError(callbackId, $"Invalid bundle name: {bundleName}", "invalid_name");
                    yield break;
                }

                if (!System.IO.File.Exists(bundlePath))
                {
                    SendError(callbackId, $"Bundle file not found: {bundlePath}", "file_not_found");
                    yield break;
                }

                var loadRequest = AssetBundle.LoadFromFileAsync(bundlePath);
                yield return loadRequest;

                if (loadRequest.assetBundle == null)
                {
                    SendError(callbackId, $"Failed to load AssetBundle: {bundleName}", "load_failed");
                    yield break;
                }

                _loadedBundles[bundleName] = loadRequest.assetBundle;
            }

            var bundle = _loadedBundles[bundleName];
            var scenePaths = bundle.GetAllScenePaths();

            if (scenePaths.Length == 0)
            {
                SendError(callbackId, $"No scenes found in bundle '{bundleName}'", "no_scenes");
                yield break;
            }

            var mode = loadMode == LOAD_MODE_ADDITIVE
                ? LoadSceneMode.Additive
                : LoadSceneMode.Single;

            var sceneLoad = SceneManager.LoadSceneAsync(scenePaths[0], mode);

            while (sceneLoad != null && !sceneLoad.isDone)
            {
                SendProgress(callbackId, sceneLoad.progress, STATUS_LOADING_SCENE);
                yield return null;
            }

            var response = new SceneLoadedResponse
            {
                callbackId = callbackId,
                sceneName = bundleName,
                success = true,
                error = "",
            };
            NativeAPI.SendToFlutter(JsonUtility.ToJson(response));
        }

        // -------------------------------------------------------------------
        // Unload bundle
        // -------------------------------------------------------------------

        /// <summary>
        /// Unload a previously loaded AssetBundle and release its resources.
        /// </summary>
        public void UnloadBundle(string bundleName)
        {
            if (_loadedBundles.TryGetValue(bundleName, out var bundle))
            {
                if (bundle != null)
                {
                    bundle.Unload(true);
                }
                _loadedBundles.Remove(bundleName);
                Debug.Log($"{LOG_PREFIX}: Unloaded bundle '{bundleName}'");
            }
            else
            {
                Debug.LogWarning($"{LOG_PREFIX}: Bundle '{bundleName}' not loaded, cannot unload");
            }
        }

        // -------------------------------------------------------------------
        // Helpers
        // -------------------------------------------------------------------

        private void SendError(string callbackId, string error, string errorType)
        {
            var response = new ErrorResponse
            {
                callbackId = callbackId,
                error = error,
                errorType = errorType,
            };
            NativeAPI.SendToFlutter(JsonUtility.ToJson(response));
        }

        private void SendProgress(string callbackId, float progress, string status)
        {
            var response = new ProgressResponse
            {
                callbackId = callbackId,
                progress = progress,
                status = status,
            };
            NativeAPI.SendToFlutter(JsonUtility.ToJson(response));
        }

        private void SendBundleLoaded(string callbackId, string bundleName, bool success, string error = "")
        {
            var response = new BundleLoadedResponse
            {
                callbackId = callbackId,
                bundleName = bundleName,
                success = success,
                error = error,
            };
            NativeAPI.SendToFlutter(JsonUtility.ToJson(response));
        }
    }
}
