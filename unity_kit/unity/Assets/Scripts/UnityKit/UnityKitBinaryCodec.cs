using System;
using System.Text;

namespace UnityKit
{
    /// <summary>
    /// Decoder/encoder for the compact binary wire format used by
    /// <c>UnityBinaryCodec</c> on the Flutter side.
    ///
    /// Frame layout (big-endian):
    /// <code>
    /// 'U' | 'K' | version | typeLen(u16) | type(utf8) | dataLen(u32) | data(utf8 json)
    /// </code>
    ///
    /// Flutter delivers the frame base64-encoded through the string-only
    /// <c>UnitySendMessage</c> transport, so <see cref="Decode"/> takes a
    /// base64 string and returns the decoded type + data JSON.
    /// </summary>
    public static class UnityKitBinaryCodec
    {
        private const byte Magic0 = 0x55; // 'U'
        private const byte Magic1 = 0x4B; // 'K'
        private const byte Version = 1;

        /// <summary>
        /// Decoded binary frame: a message <see cref="Type"/> and its raw
        /// <see cref="DataJson"/> payload (empty when the frame carried no data).
        /// </summary>
        public struct Frame
        {
            public string Type;
            public string DataJson;
        }

        /// <summary>
        /// Decodes a base64-encoded binary frame.
        /// Throws <see cref="FormatException"/> on a malformed frame.
        /// </summary>
        public static Frame Decode(string base64)
        {
            var bytes = Convert.FromBase64String(base64);
            return DecodeBytes(bytes);
        }

        /// <summary>Decodes a raw binary frame.</summary>
        public static Frame DecodeBytes(byte[] bytes)
        {
            if (bytes == null || bytes.Length < 9)
                throw new FormatException("Binary frame too short");
            if (bytes[0] != Magic0 || bytes[1] != Magic1)
                throw new FormatException("Bad binary frame magic");
            if (bytes[2] != Version)
                throw new FormatException($"Unsupported binary frame version: {bytes[2]}");

            var offset = 3;
            var typeLen = ReadUInt16(bytes, ref offset);
            if (offset + typeLen + 4 > bytes.Length)
                throw new FormatException("Binary frame type length overflow");
            var type = Encoding.UTF8.GetString(bytes, offset, typeLen);
            offset += typeLen;

            var dataLen = (int)ReadUInt32(bytes, ref offset);
            if (offset + dataLen > bytes.Length)
                throw new FormatException("Binary frame data length overflow");
            var data = dataLen > 0 ? Encoding.UTF8.GetString(bytes, offset, dataLen) : string.Empty;

            return new Frame { Type = type, DataJson = data };
        }

        /// <summary>
        /// Encodes a type + data JSON pair into a base64 binary frame, ready to
        /// hand to the native bridge for delivery to Flutter.
        /// </summary>
        public static string Encode(string type, string dataJson)
        {
            var typeBytes = Encoding.UTF8.GetBytes(type ?? string.Empty);
            var dataBytes = string.IsNullOrEmpty(dataJson)
                ? Array.Empty<byte>()
                : Encoding.UTF8.GetBytes(dataJson);

            var buffer = new byte[3 + 2 + typeBytes.Length + 4 + dataBytes.Length];
            var offset = 0;
            buffer[offset++] = Magic0;
            buffer[offset++] = Magic1;
            buffer[offset++] = Version;

            WriteUInt16(buffer, ref offset, (ushort)typeBytes.Length);
            Array.Copy(typeBytes, 0, buffer, offset, typeBytes.Length);
            offset += typeBytes.Length;

            WriteUInt32(buffer, ref offset, (uint)dataBytes.Length);
            Array.Copy(dataBytes, 0, buffer, offset, dataBytes.Length);

            return Convert.ToBase64String(buffer);
        }

        private static ushort ReadUInt16(byte[] b, ref int o)
        {
            var value = (ushort)((b[o] << 8) | b[o + 1]);
            o += 2;
            return value;
        }

        private static uint ReadUInt32(byte[] b, ref int o)
        {
            var value = ((uint)b[o] << 24) | ((uint)b[o + 1] << 16) |
                        ((uint)b[o + 2] << 8) | b[o + 3];
            o += 4;
            return value;
        }

        private static void WriteUInt16(byte[] b, ref int o, ushort value)
        {
            b[o++] = (byte)(value >> 8);
            b[o++] = (byte)(value & 0xFF);
        }

        private static void WriteUInt32(byte[] b, ref int o, uint value)
        {
            b[o++] = (byte)(value >> 24);
            b[o++] = (byte)(value >> 16);
            b[o++] = (byte)(value >> 8);
            b[o++] = (byte)(value & 0xFF);
        }
    }
}
