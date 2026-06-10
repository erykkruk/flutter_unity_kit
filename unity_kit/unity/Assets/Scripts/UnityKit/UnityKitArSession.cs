using UnityEngine;
using UnityEngine.Events;

namespace UnityKit
{
    /// <summary>
    /// AR session bridge for AR Foundation experiences.
    ///
    /// Registers under the <c>ArSession</c> target and responds to Flutter
    /// commands (<c>start</c>, <c>stop</c>, <c>setMode</c>). It deliberately
    /// does <b>not</b> reference the AR Foundation package directly, so the
    /// script compiles in any project. Wire the UnityEvents below to your
    /// <c>ARSession</c> component to actually start/stop tracking:
    ///
    /// <code>
    /// onSessionStart.AddListener(() => arSession.enabled = true);
    /// onSessionStop.AddListener(() => arSession.enabled = false);
    /// </code>
    ///
    /// For <see cref="UnityArMode.overlay"/> it clears the target camera to a
    /// transparent colour so the device feed (or Flutter content) shows through.
    /// </summary>
    public class UnityKitArSession : MonoBehaviour
    {
        public const string Target = "ArSession";

        [Tooltip("Camera whose clear flags/colour are adjusted for AR overlay. Uses Camera.main if empty.")]
        [SerializeField] private Camera targetCamera;

        [Tooltip("Invoked when Flutter requests the AR session to start.")]
        public UnityEvent onSessionStart;

        [Tooltip("Invoked when Flutter requests the AR session to stop.")]
        public UnityEvent onSessionStop;

        private Color _originalClearColor;
        private CameraClearFlags _originalClearFlags;
        private bool _cameraStateCaptured;

        void OnEnable()
        {
            MessageRouter.Register(Target, HandleMessage);
        }

        void OnDisable()
        {
            MessageRouter.Unregister(Target);
        }

        private Camera ResolveCamera() => targetCamera != null ? targetCamera : Camera.main;

        private void HandleMessage(string method, string data)
        {
            switch (method)
            {
                case "start":
                    StartSession(data);
                    break;
                case "stop":
                    StopSession();
                    break;
                case "setMode":
                    ApplyMode(data);
                    break;
                default:
                    UnityKitLogger.Warning($"ArSession: unknown method '{method}'");
                    break;
            }
        }

        /// <summary>Starts the AR session, applying <paramref name="mode"/>.</summary>
        public void StartSession(string mode)
        {
            ApplyMode(mode);
            onSessionStart?.Invoke();
            NativeAPI.SendToFlutter("{\"type\":\"ar_started\"}");
            UnityKitLogger.Info($"AR session started (mode: {mode})");
        }

        /// <summary>Stops the AR session and restores the camera.</summary>
        public void StopSession()
        {
            RestoreCamera();
            onSessionStop?.Invoke();
            NativeAPI.SendToFlutter("{\"type\":\"ar_stopped\"}");
            UnityKitLogger.Info("AR session stopped");
        }

        private void ApplyMode(string mode)
        {
            var camera = ResolveCamera();
            if (camera == null) return;

            if (!_cameraStateCaptured)
            {
                _originalClearColor = camera.backgroundColor;
                _originalClearFlags = camera.clearFlags;
                _cameraStateCaptured = true;
            }

            if (mode == "overlay")
            {
                camera.clearFlags = CameraClearFlags.SolidColor;
                camera.backgroundColor = new Color(0f, 0f, 0f, 0f);
            }
            else
            {
                RestoreCamera();
            }
        }

        private void RestoreCamera()
        {
            var camera = ResolveCamera();
            if (camera == null || !_cameraStateCaptured) return;

            camera.clearFlags = _originalClearFlags;
            camera.backgroundColor = _originalClearColor;
            _cameraStateCaptured = false;
        }
    }
}
