using NUnit.Framework;

namespace UnityKit.Tests
{
    public class UnityKitMethodDispatcherTests
    {
        private class Target
        {
            public int jumpCount;
            public string lastRaw;
            public Payload lastPayload;

            [UnityKitMethod]
            public void Jump() => jumpCount++;

            [UnityKitMethod("move")]
            public void Move(string data) => lastRaw = data;

            [UnityKitMethod]
            public void Configure(Payload payload) => lastPayload = payload;

            public void NotExposed() => jumpCount = -1;
        }

        [System.Serializable]
        public class Payload
        {
            public int value;
        }

        [Test]
        public void Build_FindsExposedMethods()
        {
            Assert.IsTrue(new UnityKitMethodDispatcher(new Target()).HasMethods);
        }

        [Test]
        public void Dispatch_InvokesNoArgMethodByDefaultName()
        {
            var target = new Target();
            new UnityKitMethodDispatcher(target).Dispatch("Jump", null);

            Assert.AreEqual(1, target.jumpCount);
        }

        [Test]
        public void Dispatch_UsesAttributeNameAndPassesRawString()
        {
            var target = new Target();
            new UnityKitMethodDispatcher(target).Dispatch("move", "payload");

            Assert.AreEqual("payload", target.lastRaw);
        }

        [Test]
        public void Dispatch_DeserializesTypedArgument()
        {
            var target = new Target();
            new UnityKitMethodDispatcher(target).Dispatch("Configure", "{\"value\":7}");

            Assert.IsNotNull(target.lastPayload);
            Assert.AreEqual(7, target.lastPayload.value);
        }

        [Test]
        public void Dispatch_UnknownMethod_DoesNotThrow()
        {
            var dispatcher = new UnityKitMethodDispatcher(new Target());

            Assert.DoesNotThrow(() => dispatcher.Dispatch("missing", null));
        }
    }
}
