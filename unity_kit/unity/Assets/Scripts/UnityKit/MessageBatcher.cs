using System.Collections.Generic;
using UnityEngine;

namespace UnityKit
{
    /// <summary>
    /// Batches outgoing messages to Flutter per frame.
    /// Sends all accumulated messages as a JSON array in LateUpdate.
    /// </summary>
    public class MessageBatcher : MonoBehaviour
    {
        private readonly List<string> _batch = new();
        private bool _hasPending = false;

        /// <summary>
        /// Queue a message to be sent in the next batch.
        /// </summary>
        public void Send(string type, string data = "")
        {
            var json = string.IsNullOrEmpty(data)
                ? $"{{\"type\":\"{type}\"}}"
                : $"{{\"type\":\"{type}\",\"data\":\"{data}\"}}";
            _batch.Add(json);
            _hasPending = true;
        }

        /// <summary>
        /// Queue a raw JSON message.
        /// </summary>
        public void SendRaw(string json)
        {
            _batch.Add(json);
            _hasPending = true;
        }

        /// <summary>
        /// Force flush all pending messages immediately.
        /// </summary>
        public void Flush()
        {
            if (!_hasPending) return;
            var batchJson = "[" + string.Join(",", _batch) + "]";
            NativeAPI.SendToFlutter(batchJson);
            _batch.Clear();
            _hasPending = false;
        }

        void LateUpdate()
        {
            Flush();
        }

        /// <summary>
        /// Number of pending messages in the current batch.
        /// </summary>
        public int PendingCount => _batch.Count;

        /// <summary>
        /// Clear all pending messages without sending.
        /// </summary>
        public void Clear()
        {
            _batch.Clear();
            _hasPending = false;
        }
    }
}
