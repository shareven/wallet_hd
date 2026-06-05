import 'dart:typed_data';
import 'package:wallet_hd/src/op.dart';

class DecodedPushData {
  int opcode;
  int number;
  int size;
  DecodedPushData({required this.opcode, required this.number, required this.size});
}
class EncodedPushData {
  int size;
  Uint8List buffer;

  EncodedPushData({required this.size, required this.buffer});
}
EncodedPushData encode(Uint8List buffer, int number, int offset) {
  var size = encodingLength(number);
  if (size == 1) {
    buffer.buffer.asByteData().setUint8(offset, number);
  } else if (size == 2) {
    buffer.buffer.asByteData().setUint8(offset, OPS['OP_PUSHDATA1']!);
    buffer.buffer.asByteData().setUint8(offset + 1, number);
  } else if (size == 3) {
    buffer.buffer.asByteData().setUint8(offset, OPS['OP_PUSHDATA2']!);
    buffer.buffer.asByteData().setUint16(offset + 1, number, Endian.little);
  } else {
    buffer.buffer.asByteData().setUint8(offset, OPS['OP_PUSHDATA4']!);
    buffer.buffer.asByteData().setUint32(offset + 1, number, Endian.little);
  }

  return EncodedPushData(
    size: size,
    buffer: buffer
  );
}
DecodedPushData? decode(Uint8List bf, int offset) {
  ByteBuffer buffer = bf.buffer;
  int opcode = buffer.asByteData().getUint8(offset);
  int number;
  int size;

  if (opcode < OPS['OP_PUSHDATA1']!) {
    number = opcode;
    size = 1;
  } else if (opcode == OPS['OP_PUSHDATA1']!) {
    if (offset + 2 > buffer.lengthInBytes) return null;
    number = buffer.asByteData().getUint8(offset + 1);
    size = 2;
  } else if (opcode == OPS['OP_PUSHDATA2']!) {
    if (offset + 3 > buffer.lengthInBytes) return null;
    number = buffer.asByteData().getUint16(offset + 1);
    size = 3;
  } else {
    if (offset + 5 > buffer.lengthInBytes) return null;
    if (opcode != OPS['OP_PUSHDATA4']!) throw ArgumentError('Unexpected opcode');
    number = buffer.asByteData().getUint32(offset + 1);
    size = 5;
  }

  return DecodedPushData(
    opcode: opcode,
    number: number,
    size: size
  );
}
int encodingLength (int i) {
  return i < OPS['OP_PUSHDATA1']! ? 1
      : i <= 0xff ? 2
      : i <= 0xffff ? 3
      : 5;
}
