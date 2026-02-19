using UnityEngine;

namespace UnityKit
{
    /// <summary>
    /// Base class for MonoBehaviours that communicate with Flutter.
    /// Auto-registers with MessageRouter on enable/disable.
    /// Override OnFlutterMessage to handle incoming messages.
    /// </summary>
    public abstract class FlutterMonoBehaviour : MonoBehaviour
    {
        [SerializeField]
        [Tooltip("Custom target name for message routing. Uses GameObject name if empty.")]
        private string targetName;

        /// <summary>
        /// The target name used for message routing.
        /// </summary>
        public string TargetName =>
            string.IsNullOrEmpty(targetName) ? gameObject.name : targetName;

        protected virtual void OnEnable()
        {
            MessageRouter.Register(TargetName, HandleMessage);
        }

        protected virtual void OnDisable()
        {
            MessageRouter.Unregister(TargetName);
        }

        private void HandleMessage(string method, string data)
        {
            OnFlutterMessage(method, data);
        }

        /// <summary>
        /// Called when a message from Flutter targets this object.
        /// </summary>
        /// <param name="method">The method name from Flutter.</param>
        /// <param name="data">The data payload (may be empty).</param>
        protected abstract void OnFlutterMessage(string method, string data);

        /// <summary>
        /// Send a typed message to Flutter.
        /// </summary>
        protected void SendToFlutter(string type, string data = "")
        {
            var json = string.IsNullOrEmpty(data)
                ? $"{{\"type\":\"{type}\"}}"
                : $"{{\"type\":\"{type}\",\"data\":\"{data}\"}}";
            NativeAPI.SendToFlutter(json);
        }

        /// <summary>
        /// Send a message to Flutter using the batcher (if available).
        /// Falls back to direct send if no batcher exists.
        /// </summary>
        protected void SendToFlutterBatched(string type, string data = "")
        {
            var batcher = FlutterBridge.Instance?.GetComponent<MessageBatcher>();
            if (batcher != null)
            {
                batcher.Send(type, data);
            }
            else
            {
                SendToFlutter(type, data);
            }
        }
    }
}
