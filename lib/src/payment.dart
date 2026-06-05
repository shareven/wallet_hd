import 'dart:typed_data';

import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:bech32/bech32.dart';

import 'package:wallet_hd/src/crypto.dart';
import 'package:wallet_hd/src/network_type.dart';
import 'package:wallet_hd/src/op.dart';
import 'package:wallet_hd/src/script.dart' as bscript;

class PaymentData {
  String? address;
  Uint8List? hash;
  Uint8List? output;
  Uint8List? pubkey;
  Uint8List? signature;
  Uint8List? input;
  Uint8List? witness;

  PaymentData({
    this.address,
    this.hash,
    this.output,
    this.pubkey,
    this.signature,
    this.input,
    this.witness,
  });
}

class P2PKH {
  PaymentData data;
  NetworkType network;

  P2PKH({required this.data, required this.network}) {
    _init();
  }

  void _init() {
    if (data.address != null) {
      _getDataFromAddress(data.address!);
    }
    if (data.hash != null) {
      _getDataFromHash();
    }
    if (data.pubkey != null) {
      data.hash = hash160(data.pubkey!);
      _getDataFromHash();
    }
    if (data.input != null) {
      final chunks = bscript.decompile(data.input!);
      if (chunks != null && chunks.length == 2) {
        data.pubkey = (chunks[1] is int)
            ? Uint8List.fromList([chunks[1] as int])
            : chunks[1] as Uint8List;
        data.signature = (chunks[0] is int)
            ? Uint8List.fromList([chunks[0] as int])
            : chunks[0] as Uint8List;
        data.hash = hash160(data.pubkey!);
        _getDataFromHash();
      }
    }
  }

  void _getDataFromAddress(String address) {
    final payload = bs58check.decode(address);
    final version = payload.buffer.asByteData().getUint8(0);
    if (version != network.pubKeyHash) {
      throw ArgumentError('Invalid version or Network mismatch');
    }
    data.hash = payload.sublist(1);
    if (data.hash!.length != 20) {
      throw ArgumentError('Invalid address');
    }
  }

  void _getDataFromHash() {
    if (data.address == null) {
      final payload = Uint8List(21);
      payload.buffer.asByteData().setUint8(0, network.pubKeyHash);
      payload.setRange(1, 21, data.hash!);
      data.address = bs58check.encode(payload);
    }
    if (data.output == null) {
      data.output = bscript.compile([
        OPS['OP_DUP'],
        OPS['OP_HASH160'],
        data.hash!,
        OPS['OP_EQUALVERIFY'],
        OPS['OP_CHECKSIG'],
      ]);
    }
  }
}

class P2WPKH {
  PaymentData data;
  NetworkType network;

  P2WPKH({required this.data, required this.network}) {
    _init();
  }

  void _init() {
    if (data.address != null) {
      _getDataFromAddress(data.address!);
    }
    if (data.hash != null) {
      _getDataFromHash();
    }
    if (data.pubkey != null) {
      data.hash = hash160(data.pubkey!);
      _getDataFromHash();
    }
  }

  void _getDataFromAddress(String address) {
    final decoded = segwit.decode(address);
    if (decoded.hrp != network.bech32) {
      throw ArgumentError('Invalid prefix or Network mismatch');
    }
    if (decoded.version != 0) {
      throw ArgumentError('Invalid address version');
    }
    final program = decoded.program;
    data.hash = Uint8List.fromList(program.map((e) => e).toList());
    if (data.hash!.length != 20) {
      throw ArgumentError('Invalid address');
    }
  }

  void _getDataFromHash() {
    if (data.output == null) {
      data.output = bscript.compile([
        OPS['OP_0'],
        data.hash!,
      ]);
    }
    if (data.address == null) {
      final program = data.hash!.toList();
      data.address =
          segwit.encode(Segwit(network.bech32, 0, program));
    }
  }
}
