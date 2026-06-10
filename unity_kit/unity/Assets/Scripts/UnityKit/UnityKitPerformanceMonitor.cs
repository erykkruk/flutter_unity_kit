using System.Globalization;
using UnityEngine;
using UnityEngine.Profiling;

namespace UnityKit
{
    /// <summary>
    /// Samples runtime performance and streams it to Flutter as <c>__perf</c>
    /// messages, surfaced on <c>UnityBridge.performanceStream</c>.
    ///
    /// Attach to the same GameObject as <see cref="FlutterBridge"/> (or any
    /// persistent object). Reports smoothed FPS, frame time and used memory at
    /// a configurable interval.
    ///
    /// Draw-call and triangle counts are intentionally not reported here: the
    /// runtime has no public cross-platform API for them (the editor-only
    /// <c>UnityEditor.UnityStats</c> does not exist in player builds). The
    /// Flutter-side <c>UnityPerformanceStats</c> still carries those fields for
    /// projects that wire up their own source.
    /// </summary>
    public class UnityKitPerformanceMonitor : MonoBehaviour
    {
        [Tooltip("Seconds between performance samples sent to Flutter.")]
        [SerializeField] private float sampleIntervalSeconds = 1.0f;

        [Tooltip("Smoothing factor for the FPS estimate (0..1, higher = smoother).")]
        [Range(0f, 0.99f)]
        [SerializeField] private float smoothing = 0.9f;

        private float _smoothedDeltaTime;
        private float _accumulator;

        void OnEnable()
        {
            _smoothedDeltaTime = Mathf.Max(Time.unscaledDeltaTime, 1e-5f);
            _accumulator = 0f;
        }

        void Update()
        {
            var delta = Mathf.Max(Time.unscaledDeltaTime, 1e-5f);
            _smoothedDeltaTime = Mathf.Lerp(delta, _smoothedDeltaTime, smoothing);

            _accumulator += Time.unscaledDeltaTime;
            if (_accumulator < sampleIntervalSeconds) return;
            _accumulator = 0f;

            Report();
        }

        private void Report()
        {
            var frameTimeMs = _smoothedDeltaTime * 1000f;
            var fps = 1f / _smoothedDeltaTime;
            var usedMemoryMb = Profiler.GetTotalAllocatedMemoryLong() / (1024f * 1024f);

            var json = string.Format(
                CultureInfo.InvariantCulture,
                "{{\"type\":\"__perf\",\"data\":{{" +
                "\"fps\":{0:0.0},\"frameTimeMs\":{1:0.00},\"usedMemoryMb\":{2:0.0}}}}}",
                fps, frameTimeMs, usedMemoryMb);

            NativeAPI.SendToFlutter(json);
        }
    }
}
