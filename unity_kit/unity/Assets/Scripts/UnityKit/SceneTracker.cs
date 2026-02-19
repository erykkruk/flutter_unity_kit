using UnityEngine;
using UnityEngine.SceneManagement;

namespace UnityKit
{
    /// <summary>
    /// Tracks Unity scene loads and notifies Flutter automatically.
    /// Attach to the same GameObject as FlutterBridge.
    /// </summary>
    public class SceneTracker : MonoBehaviour
    {
        void OnEnable()
        {
            SceneManager.sceneLoaded += OnSceneLoaded;
            SceneManager.sceneUnloaded += OnSceneUnloaded;
        }

        void OnDisable()
        {
            SceneManager.sceneLoaded -= OnSceneLoaded;
            SceneManager.sceneUnloaded -= OnSceneUnloaded;
        }

        private void OnSceneLoaded(Scene scene, LoadSceneMode mode)
        {
            NativeAPI.NotifySceneLoaded(
                scene.name,
                scene.buildIndex,
                scene.isLoaded,
                IsSceneValid(scene)
            );
        }

        private void OnSceneUnloaded(Scene scene)
        {
            NativeAPI.SendToFlutter(
                $"{{\"type\":\"scene_unloaded\",\"data\":\"{scene.name}\"}}"
            );
        }

        private static bool IsSceneValid(Scene scene)
        {
            return scene.IsValid() && scene.buildIndex >= 0;
        }
    }
}
