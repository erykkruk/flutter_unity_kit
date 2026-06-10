using NUnit.Framework;

namespace UnityKit.Tests
{
    public class MessageRouterTests
    {
        [TearDown]
        public void Cleanup() => MessageRouter.Clear();

        [Test]
        public void Register_RoutesToHandler()
        {
            string captured = null;
            MessageRouter.Register("target", (method, data) => captured = $"{method}:{data}");

            MessageRouter.Route("target", "do", "x");

            Assert.AreEqual("do:x", captured);
        }

        [Test]
        public void Unregister_RemovesHandler()
        {
            MessageRouter.Register("target", (_, __) => { });
            MessageRouter.Unregister("target");

            Assert.IsFalse(MessageRouter.HasHandler("target"));
        }

        [Test]
        public void RegisterMethods_DispatchesByMethodName()
        {
            var target = new AttributeTarget();
            MessageRouter.RegisterMethods("obj", target);

            MessageRouter.Route("obj", "Ping", null);

            Assert.AreEqual(1, target.pings);
        }

        [Test]
        public void HasHandler_ReflectsRegistration()
        {
            Assert.IsFalse(MessageRouter.HasHandler("x"));
            MessageRouter.Register("x", (_, __) => { });
            Assert.IsTrue(MessageRouter.HasHandler("x"));
        }

        private class AttributeTarget
        {
            public int pings;

            [UnityKitMethod]
            public void Ping() => pings++;
        }
    }
}
