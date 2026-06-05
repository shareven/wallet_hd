import 'dart:convert';
import 'dart:typed_data';

import 'package:crypton/crypton.dart';

class RsaProxy {
  String get privateKey => _rsaPrivateKey.toString();
  String get publicKey => _rsaPublicKey.toString();

  RSAPrivateKey _rsaPrivateKey;
  RSAPublicKey _rsaPublicKey;

  RsaProxy._(this._rsaPrivateKey, this._rsaPublicKey);

  RsaProxy(String? privateKeyString, String? publicKeyString)
      : _rsaPrivateKey = privateKeyString != null
            ? RSAPrivateKey.fromString(privateKeyString)
            : RSAKeypair.fromRandom().privateKey,
        _rsaPublicKey = publicKeyString != null
            ? RSAPublicKey.fromString(publicKeyString)
            : RSAKeypair.fromRandom().publicKey;

  Future<bool> verifySignature(String message, String signedText) async {
    try {
      bool verified = _rsaPublicKey.verifySHA256Signature(
        Uint8List.fromList(utf8.encode(message)),
        Uint8List.fromList(base64.decode(signedText)),
      );
      return verified;
    } catch (e) {
      print('rsa verifySignature error : $e');
    }
    return false;
  }

  Future<String?> sign(String message) async {
    try {
      final sigBytes = _rsaPrivateKey.createSHA256Signature(
        Uint8List.fromList(utf8.encode(message)),
      );
      return base64.encode(sigBytes);
    } catch (e) {
      print('rsa sign error : $e');
    }
    return null;
  }

  static RsaProxy create() {
    RSAKeypair rsaKeypair = RSAKeypair.fromRandom();
    return RsaProxy._(rsaKeypair.privateKey, rsaKeypair.publicKey);
  }
}
