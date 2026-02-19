using UnityEngine;

namespace UnityKit
{
    /// <summary>
    /// Handles transform manipulation from Flutter gestures.
    /// Responds to SetParameter commands for position, rotation, and scale.
    /// Attach to any GameObject that should be controlled via Flutter touch input.
    /// </summary>
    public class ObjectController : FlutterMonoBehaviour
    {
        private Vector3 initialPosition;
        private Vector3 initialScale;
        private Quaternion initialRotation;

        private float positionX;
        private float positionY;
        private float rotationX;
        private float rotationY;
        private float rotationZ;
        private float scale = 1f;

        private void Awake()
        {
            initialPosition = transform.localPosition;
            initialScale = transform.localScale;
            initialRotation = transform.localRotation;
        }

        protected override void OnFlutterMessage(string method, string data)
        {
            switch (method)
            {
                case "SetParameter":
                    HandleSetParameter(data);
                    break;
                case "ResetParameters":
                    ResetAll();
                    break;
            }
        }

        private void HandleSetParameter(string json)
        {
            var parsed = JsonUtility.FromJson<ParameterPayload>(json);
            if (parsed == null) return;

            switch (parsed.param)
            {
                case "positionX":
                    positionX = parsed.value;
                    ApplyPosition();
                    break;
                case "positionY":
                    positionY = parsed.value;
                    ApplyPosition();
                    break;
                case "rotationX":
                    rotationX = parsed.value;
                    ApplyRotation();
                    break;
                case "rotationY":
                    rotationY = parsed.value;
                    ApplyRotation();
                    break;
                case "rotationZ":
                    rotationZ = parsed.value;
                    ApplyRotation();
                    break;
                case "scale":
                    scale = parsed.value;
                    ApplyScale();
                    break;
            }
        }

        private void ApplyPosition()
        {
            transform.localPosition = initialPosition + new Vector3(positionX, positionY, 0f);
        }

        private void ApplyRotation()
        {
            transform.localRotation = initialRotation * Quaternion.Euler(rotationX, rotationY, rotationZ);
        }

        private void ApplyScale()
        {
            transform.localScale = initialScale * scale;
        }

        private void ResetAll()
        {
            positionX = 0f;
            positionY = 0f;
            rotationX = 0f;
            rotationY = 0f;
            rotationZ = 0f;
            scale = 1f;

            transform.localPosition = initialPosition;
            transform.localRotation = initialRotation;
            transform.localScale = initialScale;

            SendToFlutter("parameters_reset");
        }

        [System.Serializable]
        private class ParameterPayload
        {
            public string param;
            public float value;
        }
    }
}
