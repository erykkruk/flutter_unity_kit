using System;
using System.Collections.Generic;
using System.Reflection;
using UnityEngine;

namespace UnityKit
{
    /// <summary>
    /// Marks a method as callable from Flutter by name.
    ///
    /// Instead of hand-writing a <c>switch</c> over method names, decorate the
    /// C# methods you want to expose and register the instance once with
    /// <see cref="MessageRouter.RegisterMethods(string, object)"/>. The
    /// dispatcher then routes incoming Flutter calls to the matching method.
    ///
    /// Supported signatures:
    /// <list type="bullet">
    /// <item><c>void Method()</c></item>
    /// <item><c>void Method(string data)</c> — raw payload</item>
    /// <item><c>void Method(T data)</c> — <c>data</c> JSON-deserialized via
    /// <see cref="JsonUtility"/></item>
    /// </list>
    ///
    /// <code>
    /// public class PlayerController : MonoBehaviour
    /// {
    ///     [UnityKitMethod]                 // exposed as "Jump"
    ///     public void Jump() { /* ... */ }
    ///
    ///     [UnityKitMethod("move")]         // exposed as "move"
    ///     public void Move(Vector3Payload p) { /* ... */ }
    ///
    ///     void OnEnable() => MessageRouter.RegisterMethods("player", this);
    ///     void OnDisable() => MessageRouter.Unregister("player");
    /// }
    /// </code>
    /// </summary>
    [AttributeUsage(AttributeTargets.Method, Inherited = true, AllowMultiple = false)]
    public sealed class UnityKitMethodAttribute : Attribute
    {
        /// <summary>
        /// Optional override for the name exposed to Flutter.
        /// Defaults to the C# method name.
        /// </summary>
        public string Name { get; }

        public UnityKitMethodAttribute(string name = null)
        {
            Name = name;
        }
    }

    /// <summary>
    /// Reflects over an instance's <see cref="UnityKitMethodAttribute"/> methods
    /// and dispatches Flutter calls to them by name.
    /// </summary>
    public sealed class UnityKitMethodDispatcher
    {
        private readonly object _instance;
        private readonly Dictionary<string, MethodInfo> _methods = new();

        public UnityKitMethodDispatcher(object instance)
        {
            _instance = instance ?? throw new ArgumentNullException(nameof(instance));
            Build();
        }

        private void Build()
        {
            const BindingFlags flags = BindingFlags.Public | BindingFlags.NonPublic |
                                       BindingFlags.Instance | BindingFlags.FlattenHierarchy;

            foreach (var method in _instance.GetType().GetMethods(flags))
            {
                var attribute = method.GetCustomAttribute<UnityKitMethodAttribute>();
                if (attribute == null) continue;

                var name = string.IsNullOrEmpty(attribute.Name) ? method.Name : attribute.Name;
                _methods[name] = method;
            }
        }

        /// <summary>Whether any exposed methods were found.</summary>
        public bool HasMethods => _methods.Count > 0;

        /// <summary>
        /// Invokes the method registered under <paramref name="method"/>,
        /// passing <paramref name="data"/> deserialized to its parameter type.
        /// </summary>
        public void Dispatch(string method, string data)
        {
            if (!_methods.TryGetValue(method, out var info))
            {
                UnityKitLogger.Warning($"No [UnityKitMethod] named '{method}' on {_instance.GetType().Name}");
                return;
            }

            try
            {
                var parameters = info.GetParameters();
                if (parameters.Length == 0)
                {
                    info.Invoke(_instance, null);
                }
                else if (parameters[0].ParameterType == typeof(string))
                {
                    info.Invoke(_instance, new object[] { data });
                }
                else
                {
                    var arg = JsonUtility.FromJson(data ?? string.Empty, parameters[0].ParameterType);
                    info.Invoke(_instance, new[] { arg });
                }
            }
            catch (Exception e)
            {
                UnityKitLogger.Error($"Failed to dispatch '{method}': {e.Message}");
            }
        }
    }
}
