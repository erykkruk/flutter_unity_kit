using System;

namespace UnityKit
{
    /// <summary>
    /// Serializable message structure for Flutter-Unity communication.
    /// </summary>
    [Serializable]
    public class FlutterMessage
    {
        public string target;
        public string method;
        public string data;
    }
}
