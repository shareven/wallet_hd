import 'dart:typed_data';
import 'dart:convert';

import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:hex/hex.dart';

import 'package:wallet_hd/src/crypto.dart';
import 'package:wallet_hd/src/ecurve.dart';
import 'package:wallet_hd/src/network_type.dart';

class HDWallet {
  final Uint8List _privateKey;
  final Uint8List _publicKey;
  final Uint8List _chainCode;
  final int _depth;
  final int _index;
  final Uint8List _parentFingerprint;
  final NetworkType network;

  HDWallet._(
    this._privateKey,
    this._publicKey,
    this._chainCode,
    this._depth,
    this._index,
    this._parentFingerprint,
    this.network,
  );

  static HDWallet fromSeed(Uint8List seed, {NetworkType? network}) {
    final net = network ?? bitcoin;
    final I = hmacSHA512(
      Uint8List.fromList(utf8.encode('Bitcoin seed')),
      seed,
    );
    final IL = I.sublist(0, 32);
    final IR = I.sublist(32, 64);

    if (!isPrivate(IL)) {
      throw ArgumentError('Invalid seed');
    }

    final publicKey = pointFromScalar(IL, true)!;
    return HDWallet._(
      IL,
      publicKey,
      IR,
      0,
      0,
      Uint8List(4),
      net,
    );
  }

  HDWallet derivePath(String path) {
    HDWallet current = this;
    final segments = path.split('/');
    for (final segment in segments) {
      if (segment == 'm') continue;
      final hardened = segment.endsWith("'");
      final indexStr = segment.replaceAll("'", '');
      int index = int.parse(indexStr);
      if (hardened) index += 0x80000000;
      current = current._derive(index);
    }
    return current;
  }

  HDWallet _derive(int index) {
    final hardened = index >= 0x80000000;
    Uint8List data;
    if (hardened) {
      data = Uint8List(37);
      data[0] = 0x00;
      data.setRange(1, 33, _privateKey);
      data.buffer.asByteData().setUint32(33, index, Endian.big);
    } else {
      data = Uint8List(37);
      data.setRange(0, 33, _publicKey);
      data.buffer.asByteData().setUint32(33, index, Endian.big);
    }

    final I = hmacSHA512(_chainCode, data);
    final IL = I.sublist(0, 32);
    final IR = I.sublist(32, 64);

    final ilInt = fromBuffer(IL);
    final keyInt = fromBuffer(_privateKey);
    final childKeyInt = (ilInt + keyInt) % n;

    if (childKeyInt == BigInt.zero) {
      throw ArgumentError('Invalid child key');
    }

    final childKey = toBuffer(childKeyInt);
    final childPubKey = pointFromScalar(childKey, true);
    if (childPubKey == null) {
      throw ArgumentError('Invalid child key derivation');
    }

    return HDWallet._(
      childKey,
      childPubKey,
      IR,
      _depth + 1,
      index,
      hash160(_publicKey).sublist(0, 4),
      network,
    );
  }

  String get address {
    final hash = hash160(_publicKey);
    final payload = Uint8List(21);
    payload.buffer.asByteData().setUint8(0, network.pubKeyHash);
    payload.setRange(1, 21, hash);
    return bs58check.encode(payload);
  }

  String get privKey {
    return HEX.encode(_privateKey);
  }

  String get wif {
    final compressed = Uint8List(34);
    compressed.buffer.asByteData().setUint8(0, network.wif);
    compressed.setRange(1, 33, _privateKey);
    compressed.buffer.asByteData().setUint8(33, 0x01);
    return bs58check.encode(compressed);
  }

  Uint8List get publicKey => _publicKey;
  Uint8List get privateKey => _privateKey;
  Uint8List get chainCode => _chainCode;
  int get depth => _depth;
  int get index => _index;
  Uint8List get identifier => hash160(_publicKey);
  Uint8List get fingerprint => identifier.sublist(0, 4);

  String get base58 {
    final version = network.bip32.public;
    final buffer = Uint8List(78);
    buffer.buffer.asByteData().setUint32(0, version, Endian.big);
    buffer.buffer.asByteData().setUint8(4, _depth);
    buffer.setRange(5, 9, _parentFingerprint);
    buffer.buffer.asByteData().setUint32(9, _index, Endian.big);
    buffer.setRange(13, 45, _chainCode);
    buffer.buffer.asByteData().setUint8(45, 0x00);
    buffer.setRange(46, 78, _privateKey);

    final payload = Uint8List(buffer.length + 4);
    payload.setRange(0, buffer.length, buffer);
    final checksum = hash256(buffer);
    payload.setRange(buffer.length, buffer.length + 4, checksum.sublist(0, 4));
    return bs58check.encode(payload);
  }
}
