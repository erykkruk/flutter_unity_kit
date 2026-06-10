using System;
using NUnit.Framework;

namespace UnityKit.Tests
{
    public class UnityKitBinaryCodecTests
    {
        [Test]
        public void EncodeDecode_RoundTripsTypeAndData()
        {
            var base64 = UnityKitBinaryCodec.Encode("Move", "{\"x\":1}");
            var frame = UnityKitBinaryCodec.Decode(base64);

            Assert.AreEqual("Move", frame.Type);
            Assert.AreEqual("{\"x\":1}", frame.DataJson);
        }

        [Test]
        public void EncodeDecode_EmptyData()
        {
            var frame = UnityKitBinaryCodec.Decode(UnityKitBinaryCodec.Encode("Ping", null));

            Assert.AreEqual("Ping", frame.Type);
            Assert.AreEqual(string.Empty, frame.DataJson);
        }

        [Test]
        public void DecodeBytes_GoldenFrame_MatchesDartWireFormat()
        {
            // Cross-language golden frame produced by the Dart UnityBinaryCodec
            // for a message with type "Hi" and no data:
            // 'U','K', version 1, typeLen=2, "Hi", dataLen=0.
            byte[] bytes =
            {
                0x55, 0x4B, 0x01, 0x00, 0x02, 0x48, 0x69, 0x00, 0x00, 0x00, 0x00
            };

            var frame = UnityKitBinaryCodec.DecodeBytes(bytes);

            Assert.AreEqual("Hi", frame.Type);
            Assert.AreEqual(string.Empty, frame.DataJson);
        }

        [Test]
        public void DecodeBytes_BadMagic_Throws()
        {
            byte[] bytes = { 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };

            Assert.Throws<FormatException>(() => UnityKitBinaryCodec.DecodeBytes(bytes));
        }

        [Test]
        public void DecodeBytes_TooShort_Throws()
        {
            Assert.Throws<FormatException>(
                () => UnityKitBinaryCodec.DecodeBytes(new byte[] { 0x55, 0x4B }));
        }
    }
}
