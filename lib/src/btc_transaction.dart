import 'dart:typed_data';

import 'package:hex/hex.dart';

import 'package:wallet_hd/src/crypto.dart';
import 'package:wallet_hd/src/ec_pair.dart';
import 'package:wallet_hd/src/ecurve.dart' as ec;
import 'package:wallet_hd/src/network_type.dart';
import 'package:wallet_hd/src/op.dart';
import 'package:wallet_hd/src/script.dart' as bscript;

class BtcTransactionInput {
  final String txHash;
  final int vout;
  Uint8List? scriptSig;
  int sequence;

  BtcTransactionInput({
    required this.txHash,
    required this.vout,
    this.scriptSig,
    this.sequence = 0xffffffff,
  });
}

class BtcTransactionOutput {
  final int value;
  final Uint8List scriptPubKey;

  BtcTransactionOutput({
    required this.value,
    required this.scriptPubKey,
  });
}

class BtcTransaction {
  final int version;
  final List<BtcTransactionInput> inputs;
  final List<BtcTransactionOutput> outputs;
  final int locktime;

  BtcTransaction({
    this.version = 1,
    required this.inputs,
    required this.outputs,
    this.locktime = 0,
  });

  Uint8List toBytes() {
    final chunks = <Uint8List>[];

    final versionBytes = Uint8List(4);
    versionBytes.buffer.asByteData().setUint32(0, version, Endian.little);
    chunks.add(versionBytes);

    chunks.add(encodeVarint(inputs.length));
    for (final input in inputs) {
      final hashBytes = _reverseBytes(
          Uint8List.fromList(HEX.decode(input.txHash)));
      chunks.add(hashBytes);

      final voutBytes = Uint8List(4);
      voutBytes.buffer.asByteData().setUint32(0, input.vout, Endian.little);
      chunks.add(voutBytes);

      final script = input.scriptSig ?? Uint8List(0);
      chunks.add(encodeVarint(script.length));
      if (script.isNotEmpty) chunks.add(script);

      final seqBytes = Uint8List(4);
      seqBytes.buffer.asByteData().setUint32(0, input.sequence, Endian.little);
      chunks.add(seqBytes);
    }

    chunks.add(encodeVarint(outputs.length));
    for (final output in outputs) {
      final valueBytes = Uint8List(8);
      final bd = valueBytes.buffer.asByteData();
      final v = BigInt.from(output.value);
      for (int j = 0; j < 8; j++) {
        bd.setUint8(j, (v >> (j * 8) & BigInt.from(0xff)).toInt());
      }
      chunks.add(valueBytes);

      chunks.add(encodeVarint(output.scriptPubKey.length));
      chunks.add(output.scriptPubKey);
    }

    final locktimeBytes = Uint8List(4);
    locktimeBytes.buffer.asByteData().setUint32(0, locktime, Endian.little);
    chunks.add(locktimeBytes);

    return _concat(chunks);
  }

  String toHex() {
    return HEX.encode(toBytes());
  }

  String getId() {
    return HEX.encode(_reverseBytes(hash256(toBytes())));
  }
}

class TransactionBuilder {
  final NetworkType network;
  final List<BtcTransactionInput> _inputs = [];
  final List<BtcTransactionOutput> _outputs = [];
  final Map<int, Uint8List> _signatures = {};
  final Map<int, Uint8List> _pubkeys = {};

  TransactionBuilder({required this.network});

  List<BtcTransactionInput> get inputs => _inputs;

  int addInput(String txHash, int vout) {
    _inputs.add(BtcTransactionInput(txHash: txHash, vout: vout));
    return _inputs.length - 1;
  }

  int addOutput(Uint8List scriptPubKey, int value) {
    _outputs
        .add(BtcTransactionOutput(scriptPubKey: scriptPubKey, value: value));
    return _outputs.length - 1;
  }

  void sign({required int vin, required ECPair keyPair}) {
    final pubkey = keyPair.publicKey;
    _pubkeys[vin] = pubkey;

    final sighash = _hashForSignature(vin, pubkey);
    final signature = ec.sign(sighash, keyPair.privateKey);
    final derSig = bscript.encodeSignature(signature, 0x01);

    _signatures[vin] = derSig;
  }

  Uint8List _hashForSignature(int vin, Uint8List pubkey) {
    final pkHash = hash160(pubkey);
    final scriptPubKey = bscript.compile([
      OPS['OP_DUP'],
      OPS['OP_HASH160'],
      pkHash,
      OPS['OP_EQUALVERIFY'],
      OPS['OP_CHECKSIG'],
    ]);

    final inputs = <BtcTransactionInput>[];
    for (int i = 0; i < _inputs.length; i++) {
      final input = _inputs[i];
      if (i == vin) {
        inputs.add(BtcTransactionInput(
          txHash: input.txHash,
          vout: input.vout,
          scriptSig: scriptPubKey,
          sequence: input.sequence,
        ));
      } else {
        inputs.add(BtcTransactionInput(
          txHash: input.txHash,
          vout: input.vout,
          scriptSig: Uint8List(0),
          sequence: input.sequence,
        ));
      }
    }

    final tx = BtcTransaction(inputs: inputs, outputs: _outputs);
    final txBytes = tx.toBytes();

    final hashTypeBytes = Uint8List(4);
    hashTypeBytes.buffer.asByteData().setUint32(0, 1, Endian.little);

    final preimage = Uint8List(txBytes.length + 4);
    preimage.setRange(0, txBytes.length, txBytes);
    preimage.setRange(txBytes.length, txBytes.length + 4, hashTypeBytes);

    return hash256(preimage);
  }

  BtcTransaction buildIncomplete() {
    final inputs = <BtcTransactionInput>[];
    for (int i = 0; i < _inputs.length; i++) {
      final input = _inputs[i];
      Uint8List? scriptSig;

      if (_signatures.containsKey(i) && _pubkeys.containsKey(i)) {
        scriptSig = bscript.compile([_signatures[i]!, _pubkeys[i]!]);
      }

      inputs.add(BtcTransactionInput(
        txHash: input.txHash,
        vout: input.vout,
        scriptSig: scriptSig,
        sequence: input.sequence,
      ));
    }

    return BtcTransaction(inputs: inputs, outputs: List.from(_outputs));
  }
}

Uint8List _reverseBytes(Uint8List bytes) {
  final reversed = Uint8List(bytes.length);
  for (int i = 0; i < bytes.length; i++) {
    reversed[i] = bytes[bytes.length - 1 - i];
  }
  return reversed;
}

Uint8List _concat(List<Uint8List> chunks) {
  int totalLength = 0;
  for (final chunk in chunks) {
    totalLength += chunk.length;
  }
  final result = Uint8List(totalLength);
  int offset = 0;
  for (final chunk in chunks) {
    result.setRange(offset, offset + chunk.length, chunk);
    offset += chunk.length;
  }
  return result;
}
