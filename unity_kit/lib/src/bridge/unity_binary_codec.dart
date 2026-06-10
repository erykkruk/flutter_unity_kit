import 'dart:convert';
import 'dart:typed_data';

import '../exceptions/bridge_exception.dart';
import '../models/unity_message.dart';

/// Compact binary wire format for [UnityMessage].
///
/// JSON envelopes repeat the `type`/`data` keys on every send. For
/// high-frequency traffic (per-frame transforms, input deltas) the binary
/// frame removes that overhead and keeps payloads small.
///
/// Frame layout (big-endian):
///
/// ```text
/// +--------+--------+---------+----------+-----------+---------+-----------+
/// | 'U'    | 'K'    | version | typeLen  | type ...  | dataLen | data ...  |
/// | 1 byte | 1 byte | 1 byte  | uint16   | utf8      | uint32  | utf8 JSON |
/// +--------+--------+---------+----------+-----------+---------+-----------+
/// ```
///
/// `data` holds the UTF-8 JSON encoding of [UnityMessage.data] (empty when
/// `null`). The codec is dependency-free and symmetric with the C#
/// `UnityKitBinaryCodec` used inside Unity.
///
/// Example:
/// ```dart
/// final bytes = UnityBinaryCodec.encode(
///   UnityMessage.command('Move', {'x': 1.0, 'y': 2.0}),
/// );
/// final message = UnityBinaryCodec.decode(bytes);
/// ```
abstract final class UnityBinaryCodec {
  /// First magic byte (`'U'`).
  static const int magic0 = 0x55;

  /// Second magic byte (`'K'`).
  static const int magic1 = 0x4B;

  /// Current frame version. Bumped on breaking wire changes.
  static const int version = 1;

  static const int _headerByteCount = 3; // magic0 + magic1 + version

  /// Encodes [message] into a binary [UnityBinaryCodec] frame.
  static Uint8List encode(UnityMessage message) {
    final typeBytes = utf8.encode(message.type);
    final dataBytes = message.data == null
        ? const <int>[]
        : utf8.encode(json.encode(message.data));

    if (typeBytes.length > 0xFFFF) {
      throw const BridgeException(
        message: 'UnityMessage type exceeds the 65535-byte binary limit',
      );
    }

    final total =
        _headerByteCount + 2 + typeBytes.length + 4 + dataBytes.length;
    final buffer = Uint8List(total);
    final view = ByteData.view(buffer.buffer);
    var offset = 0;

    buffer[offset++] = magic0;
    buffer[offset++] = magic1;
    buffer[offset++] = version;

    view.setUint16(offset, typeBytes.length, Endian.big);
    offset += 2;
    buffer.setRange(offset, offset + typeBytes.length, typeBytes);
    offset += typeBytes.length;

    view.setUint32(offset, dataBytes.length, Endian.big);
    offset += 4;
    buffer.setRange(offset, offset + dataBytes.length, dataBytes);

    return buffer;
  }

  /// Decodes a binary frame produced by [encode] back into a [UnityMessage].
  ///
  /// Throws [BridgeException] when [bytes] is not a valid frame.
  static UnityMessage decode(Uint8List bytes) {
    if (bytes.length < _headerByteCount + 6) {
      throw const BridgeException(message: 'Binary frame too short');
    }
    if (bytes[0] != magic0 || bytes[1] != magic1) {
      throw const BridgeException(message: 'Bad binary frame magic');
    }
    if (bytes[2] != version) {
      throw BridgeException(
        message: 'Unsupported binary frame version: ${bytes[2]}',
      );
    }

    final view = ByteData.view(bytes.buffer, bytes.offsetInBytes);
    var offset = _headerByteCount;

    final typeLen = view.getUint16(offset, Endian.big);
    offset += 2;
    if (offset + typeLen + 4 > bytes.length) {
      throw const BridgeException(message: 'Binary frame type length overflow');
    }
    final type = utf8.decode(bytes.sublist(offset, offset + typeLen));
    offset += typeLen;

    final dataLen = view.getUint32(offset, Endian.big);
    offset += 4;
    if (offset + dataLen > bytes.length) {
      throw const BridgeException(message: 'Binary frame data length overflow');
    }

    Map<String, dynamic>? data;
    if (dataLen > 0) {
      final decoded =
          json.decode(utf8.decode(bytes.sublist(offset, offset + dataLen)));
      data = decoded is Map<String, dynamic> ? decoded : {'value': decoded};
    }

    return UnityMessage(type: type, data: data);
  }

  /// Whether [bytes] starts with a valid [UnityBinaryCodec] magic + version.
  static bool isBinaryFrame(Uint8List bytes) =>
      bytes.length >= _headerByteCount &&
      bytes[0] == magic0 &&
      bytes[1] == magic1 &&
      bytes[2] == version;
}

/// Sequential writer for compact, typed binary payloads.
///
/// Use this when you want to hand-pack a payload instead of letting
/// [UnityBinaryCodec] JSON-encode the `data` map — e.g. streaming a
/// transform every frame.
///
/// Every `write*` call appends in order; pair it with a matching
/// [UnityBinaryReader] on the receiving side.
///
/// Example:
/// ```dart
/// final bytes = (UnityBinaryWriter()
///       ..writeString('player')
///       ..writeFloat64(x)
///       ..writeFloat64(y))
///     .takeBytes();
/// ```
class UnityBinaryWriter {
  // copy: true — every add() snapshots the bytes immediately, so the shared
  // [_scratch] scratch buffer can be safely reused across writes.
  final BytesBuilder _builder = BytesBuilder(copy: true);
  final ByteData _scratch = ByteData(8);

  /// Appends a signed 32-bit integer (big-endian).
  void writeInt32(int value) {
    _scratch.setInt32(0, value, Endian.big);
    _builder.add(_scratch.buffer.asUint8List(0, 4));
  }

  /// Appends a signed 64-bit integer (big-endian).
  void writeInt64(int value) {
    _scratch.setInt64(0, value, Endian.big);
    _builder.add(_scratch.buffer.asUint8List(0, 8));
  }

  /// Appends a 64-bit IEEE-754 double (big-endian).
  void writeFloat64(double value) {
    _scratch.setFloat64(0, value, Endian.big);
    _builder.add(_scratch.buffer.asUint8List(0, 8));
  }

  /// Appends a single boolean as one byte (`0` or `1`).
  void writeBool(bool value) => _builder.addByte(value ? 1 : 0);

  /// Appends a length-prefixed UTF-8 string (uint32 length + bytes).
  void writeString(String value) {
    final bytes = utf8.encode(value);
    _scratch.setUint32(0, bytes.length, Endian.big);
    _builder.add(_scratch.buffer.asUint8List(0, 4));
    _builder.add(bytes);
  }

  /// Returns the accumulated bytes and clears the writer.
  Uint8List takeBytes() => _builder.takeBytes();
}

/// Sequential reader matching [UnityBinaryWriter].
///
/// Reads fields back in the exact order they were written. Throws
/// [BridgeException] when a read runs past the end of the buffer.
class UnityBinaryReader {
  /// Creates a reader over [bytes].
  UnityBinaryReader(Uint8List bytes)
      : _bytes = bytes,
        _view = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);

  final Uint8List _bytes;
  final ByteData _view;
  int _offset = 0;

  /// Whether there are unread bytes remaining.
  bool get hasMore => _offset < _bytes.length;

  /// Reads a signed 32-bit integer.
  int readInt32() {
    _require(4);
    final value = _view.getInt32(_offset, Endian.big);
    _offset += 4;
    return value;
  }

  /// Reads a signed 64-bit integer.
  int readInt64() {
    _require(8);
    final value = _view.getInt64(_offset, Endian.big);
    _offset += 8;
    return value;
  }

  /// Reads a 64-bit IEEE-754 double.
  double readFloat64() {
    _require(8);
    final value = _view.getFloat64(_offset, Endian.big);
    _offset += 8;
    return value;
  }

  /// Reads a single boolean byte.
  bool readBool() {
    _require(1);
    return _bytes[_offset++] != 0;
  }

  /// Reads a length-prefixed UTF-8 string.
  String readString() {
    final length = readInt32();
    _require(length);
    final value = utf8.decode(_bytes.sublist(_offset, _offset + length));
    _offset += length;
    return value;
  }

  void _require(int count) {
    if (_offset + count > _bytes.length) {
      throw const BridgeException(
        message: 'UnityBinaryReader read past end of buffer',
      );
    }
  }
}
