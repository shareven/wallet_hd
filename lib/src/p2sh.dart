import 'dart:typed_data';
import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:wallet_hd/src/script.dart' as bscript;
import 'package:wallet_hd/src/crypto.dart';
import 'package:wallet_hd/src/ecurve.dart';
import 'package:wallet_hd/src/network_type.dart';
import 'package:wallet_hd/src/op.dart';
import 'package:wallet_hd/src/payment.dart';

class P2SH {
  PaymentData data;
  NetworkType network;
  P2SH({required this.data, required this.network}) {
    _init();
  }
  _init() {
    if (data.address != null) {
      _getDataFromAddress(data.address!);
      _getDataFromHash();
    } else if (data.hash != null) {
      _getDataFromHash();
    } else if (data.output != null) {
      if (!isValidOutput(data.output!))
        throw ArgumentError('Output is invalid');
      data.hash = data.output!.sublist(2, 22);
      _getDataFromHash();
    } else if (data.pubkey != null) {
      data.hash = hash160(data.pubkey!);
      _getDataFromHash();
      _getDataFromChunk();
    } else if (data.input != null) {
      List<dynamic>? _chunks = bscript.decompile(data.input!);
      _getDataFromChunk(_chunks);
      if (_chunks == null || _chunks.length != 2) throw ArgumentError('Input is invalid');
      if (!bscript.isCanonicalScriptSignature(_chunks[0] is Uint8List ? _chunks[0] : Uint8List.fromList([_chunks[0] as int])))
        throw ArgumentError('Input has invalid signature');
      if (!isPoint(_chunks[1] is Uint8List ? _chunks[1] : Uint8List.fromList([_chunks[1] as int])))
        throw ArgumentError('Input has invalid pubkey');
    } else {
      throw ArgumentError("Not enough data");
    }
  }

  void _getDataFromChunk([List<dynamic>? _chunks]) {
    if (data.pubkey == null && _chunks != null) {
      data.pubkey = (_chunks[1] is int)
          ? Uint8List.fromList([_chunks[1] as int])
          : _chunks[1] as Uint8List;
      data.hash = hash160(data.pubkey!);
      _getDataFromHash();
    }
    if (data.signature == null && _chunks != null)
      data.signature = (_chunks[0] is int)
          ? Uint8List.fromList([_chunks[0] as int])
          : _chunks[0] as Uint8List;
    if (data.input == null && data.pubkey != null && data.signature != null) {
      data.input = bscript.compile([data.signature, data.pubkey]);
    }
  }

  void _getDataFromHash() {
    if (data.address == null) {
      final payload = Uint8List(21);
      payload.buffer.asByteData().setUint8(0, network.pubKeyHash);
      payload.setRange(1, payload.length, data.hash!);
      data.address = bs58check.encode(payload);
    }
    if (data.output == null) {
      data.output =
          bscript.compile([OPS['OP_HASH160'], data.hash!, OPS['OP_EQUAL']]);
    }
  }

  void _getDataFromAddress(String address) {
    Uint8List payload = bs58check.decode(address);
    final version = payload.buffer.asByteData().getUint8(0);
    if (version != network.scriptHash)
      throw ArgumentError('Invalid version or Network mismatch');
    data.hash = payload.sublist(1);
    if (data.hash!.length != 20) throw ArgumentError('Invalid address');
  }
}

bool isValidOutput(Uint8List data) {
  return data.length == 23 &&
      data[0] == OPS['OP_HASH160'] &&
      data[1] == 0x14 &&
      data[22] == OPS['OP_EQUAL'];
}
