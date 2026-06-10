using System;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace UnityKit
{
    /// <summary>
    /// High-level game lifecycle manager bridging Flutter commands to Unity.
    ///
    /// Subscribes to <see cref="FlutterBridge.OnTypedMessage"/> and handles a
    /// small vocabulary of control messages sent from Flutter:
    /// <list type="bullet">
    /// <item><c>LoadScene</c> — <c>{"name":"Level1","mode":"single|additive"}</c></item>
    /// <item><c>UnloadScene</c> — <c>{"name":"Level1"}</c></item>
    /// <item><c>SetTargetFrameRate</c> — <c>{"value":60}</c></item>
    /// <item><c>PauseGame</c> / <c>ResumeGame</c> — toggles <c>Time.timeScale</c></item>
    /// </list>
    ///
    /// Auto-creates at runtime, so projects only need to opt in by including
    /// the script. Other systems can hook <see cref="OnGamePaused"/> /
    /// <see cref="OnGameResumed"/>.
    /// </summary>
    public class UnityKitGameManager : MonoBehaviour
    {
        public static UnityKitGameManager Instance { get; private set; }

        /// <summary>Raised when the game is paused via Flutter.</summary>
        public event Action OnGamePaused;

        /// <summary>Raised when the game is resumed via Flutter.</summary>
        public event Action OnGameResumed;

        /// <summary>Initial scene name forwarded by the native host (may be empty).</summary>
        public string InitialSceneName { get; private set; }

        /// <summary>Initial AR mode forwarded by the native host (`none` by default).</summary>
        public string InitialArMode { get; private set; } = "none";

        private float _resumeTimeScale = 1f;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void AutoCreate()
        {
            if (Instance != null) return;

            var go = new GameObject("UnityKitGameManager");
            go.AddComponent<UnityKitGameManager>();
            UnityKitLogger.Info("UnityKitGameManager auto-created");
        }

        void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }
            Instance = this;
            DontDestroyOnLoad(gameObject);
        }

        void OnEnable()
        {
            if (FlutterBridge.Instance != null)
            {
                FlutterBridge.Instance.OnTypedMessage += HandleTyped;
            }
        }

        void OnDisable()
        {
            if (FlutterBridge.Instance != null)
            {
                FlutterBridge.Instance.OnTypedMessage -= HandleTyped;
            }
        }

        private void HandleTyped(string type, string rawJson)
        {
            switch (type)
            {
                case "LoadScene":
                    LoadScene(JsonUtility.FromJson<ScenePayload>(rawJson)?.data);
                    break;
                case "UnloadScene":
                    UnloadScene(JsonUtility.FromJson<ScenePayload>(rawJson)?.data);
                    break;
                case "SetTargetFrameRate":
                    SetTargetFrameRate(JsonUtility.FromJson<RatePayload>(rawJson)?.data);
                    break;
                case "PauseGame":
                    PauseGame();
                    break;
                case "ResumeGame":
                    ResumeGame();
                    break;
                case "__unitykit_init":
                    HandleInit(JsonUtility.FromJson<InitPayload>(rawJson)?.data);
                    break;
            }
        }

        /// <summary>
        /// Consumes the `__unitykit_init` message forwarded by the native host,
        /// carrying the Dart `UnityConfig` scene name and AR mode. Stores both
        /// for inspection and starts the AR session when a mode is requested.
        /// The scene is intentionally not auto-loaded — call
        /// <see cref="LoadInitialScene"/> if you want that behaviour.
        /// </summary>
        public void HandleInit(InitData data)
        {
            if (data == null) return;

            InitialSceneName = data.sceneName;
            InitialArMode = string.IsNullOrEmpty(data.arMode) ? "none" : data.arMode;

            if (InitialArMode != "none")
            {
                MessageRouter.Route(UnityKitArSession.Target, "start", InitialArMode);
            }
        }

        /// <summary>
        /// Loads <see cref="InitialSceneName"/> if it is set and not already
        /// the active scene. Opt-in helper for apps that want the native
        /// `sceneName` to drive the initial load.
        /// </summary>
        public void LoadInitialScene()
        {
            if (string.IsNullOrEmpty(InitialSceneName)) return;
            if (SceneManager.GetActiveScene().name == InitialSceneName) return;

            LoadScene(new SceneData { name = InitialSceneName, mode = "single" });
        }

        /// <summary>Loads a scene by name, additively or single.</summary>
        public void LoadScene(SceneData data)
        {
            if (data == null || string.IsNullOrEmpty(data.name)) return;

            var mode = data.mode == "additive" ? LoadSceneMode.Additive : LoadSceneMode.Single;
            SceneManager.LoadSceneAsync(data.name, mode);
            UnityKitLogger.Info($"Loading scene '{data.name}' ({mode})");
        }

        /// <summary>Unloads a scene by name.</summary>
        public void UnloadScene(SceneData data)
        {
            if (data == null || string.IsNullOrEmpty(data.name)) return;

            SceneManager.UnloadSceneAsync(data.name);
            UnityKitLogger.Info($"Unloading scene '{data.name}'");
        }

        /// <summary>Sets the application target frame rate.</summary>
        public void SetTargetFrameRate(RateData data)
        {
            if (data == null || data.value <= 0) return;

            Application.targetFrameRate = data.value;
            UnityKitLogger.Info($"Target frame rate set to {data.value}");
        }

        /// <summary>Pauses gameplay by zeroing the time scale.</summary>
        public void PauseGame()
        {
            _resumeTimeScale = Time.timeScale > 0 ? Time.timeScale : 1f;
            Time.timeScale = 0f;
            OnGamePaused?.Invoke();
            NativeAPI.SendToFlutter("{\"type\":\"game_paused\"}");
        }

        /// <summary>Resumes gameplay, restoring the prior time scale.</summary>
        public void ResumeGame()
        {
            Time.timeScale = _resumeTimeScale;
            OnGameResumed?.Invoke();
            NativeAPI.SendToFlutter("{\"type\":\"game_resumed\"}");
        }

        void OnDestroy()
        {
            if (Instance == this) Instance = null;
        }

        [Serializable]
        public class SceneData
        {
            public string name;
            public string mode;
        }

        [Serializable]
        public class RateData
        {
            public int value;
        }

        [Serializable]
        public class InitData
        {
            public string sceneName;
            public string arMode;
        }

        [Serializable]
        private class ScenePayload
        {
            public SceneData data;
        }

        [Serializable]
        private class RatePayload
        {
            public RateData data;
        }

        [Serializable]
        private class InitPayload
        {
            public InitData data;
        }
    }
}
