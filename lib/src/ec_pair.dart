import 'dart:typed_data';

import 'package:bs58check/bs58check.dart' as bs58check;

import 'package:wallet_hd/src/ecurve.dart';
import 'package:wallet_hd/src/network_type.dart';

class ECPair {
  final Uint8List _privateKey;
  final NetworkType network;
  final bool compressed;

  ECPair._(this._privateKey, this.network, this.compressed);

  static ECPair fromWIF(String wif, {NetworkType? network}) {
    final decoded = bs58check.decode(wif);
    final net = network ?? bitcoin;

    if (decoded.length == 34 && decoded[33] == 0x01) {
      if (decoded[0] != net.wif) {
        throw ArgumentError('Invalid network version');
      }
      final privateKey = decoded.sublist(1, 33);
      if (!isPrivate(privateKey)) {
        throw ArgumentError('Invalid private key');
      }
      return ECPair._(privateKey, net, true);
    }

    if (decoded.length == 33) {
      if (decoded[0] != net.wif) {
        throw ArgumentError('Invalid network version');
      }
      final privateKey = decoded.sublist(1, 33);
      if (!isPrivate(privateKey)) {
        throw ArgumentError('Invalid private key');
      }
      return ECPair._(privateKey, net, false);
    }

    throw ArgumentError('Invalid WIF length');
  }

  Uint8List get privateKey => _privateKey;

  Uint8List get publicKey {
    final pub = pointFromScalar(_privateKey, compressed);
    if (pub == null) {
      throw StateError('Invalid key: cannot derive public key');
    }
    return pub;
  }
}
