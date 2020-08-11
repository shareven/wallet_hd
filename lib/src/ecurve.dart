import 'dart:typed_data';
import 'package:hex/hex.dart';
import "package:pointycastle/ecc/curves/secp256k1.dart";
import "package:pointycastle/api.dart" show PrivateKeyParameter, PublicKeyParameter;
import 'package:pointycastle/ecc/api.dart' show ECPrivateKey, ECPublicKey, ECSignature, ECPoint;
import "package:pointycastle/signers/ecdsa_signer.dart";
import 'package:pointycastle/macs/hmac.dart';
import "package:pointycastle/digests/sha256.dart";
import 'package:wallet_hd/src/handle_big_int.dart';

final zERO32 = Uint8List.fromList(List.generate(32, (index) => 0));
final ecGroupORDER = HEX.decode("fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141");
final ecP = HEX.decode("fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f");
final secp256k1 = new ECCurve_secp256k1();
final n = secp256k1.n;
final G = secp256k1.G;
BigInt nDiv2 = n >> 1;
const THROW_BAD_PRIVATE = 'Expected Private';
const THROW_BAD_POINT = 'Expected Point';
const THROW_BAD_TWEAK = 'Expected Tweak';
const THROW_BAD_HASH = 'Expected Hash';
const THROW_BAD_SIGNATURE = 'Expected Signature';

bool isPrivate (Uint8List x) {
  if (!isScalar(x)) return false;
  return _compare(x, zERO32) > 0 && // > 0
      _compare(x, ecGroupORDER) < 0; // < G
}
bool isPoint(Uint8List p) {
  if (p.length < 33) {
    return false;
  }
  var t = p[0];
  var x = p.sublist(1, 33);

  if (_compare(x, zERO32) == 0) {
    return false;
  }
  if (_compare(x, ecP) == 1) {
    return false;
  }
  try {
    decodeFrom(p);
  } catch(err) {
    return false;
  }
  if ((t == 0x02 || t == 0x03) && p.length == 33) {
    return true;
  }
  var y = p.sublist(33);
  if (_compare(y, zERO32) == 0) {
    return false;
  }
  if (_compare(y, ecP) == 1) {
    return false;
  }
  if (t == 0x04 && p.length == 65) {
    return true;
  }
  return false;
}
bool isScalar (Uint8List x) {
  return x.length == 32;
}
bool isOrderScalar (x) {
  if (!isScalar(x)) return false;
  return _compare(x, ecGroupORDER) < 0; // < G
}
bool isSignature (Uint8List value) {
  Uint8List r = value.sublist(0, 32);
  Uint8List s = value.sublist(32, 64);
  return value.length == 64 &&
  _compare(r, ecGroupORDER) < 0 &&
  _compare(s, ecGroupORDER) < 0;
}
bool _isPointCompressed (Uint8List p) {
  return p[0] != 0x04;
}
bool assumeCompression(bool value, Uint8List pubkey) {
  if (value == null && pubkey != null) return _isPointCompressed(pubkey);
  if (value == null) return true;
  return value;
}
Uint8List pointFromScalar(Uint8List d, bool _compressed) {
  if (!isPrivate(d)) throw new ArgumentError(THROW_BAD_PRIVATE);
  BigInt dd = fromBuffer(d);
  ECPoint pp = G * dd;
  if (pp.isInfinity) return null;
  return getEncoded(pp, _compressed);
}
Uint8List pointAddScalar(Uint8List p,Uint8List tweak, bool _compressed) {
  if (!isPoint(p)) throw new ArgumentError(THROW_BAD_POINT);
  if (!isOrderScalar(tweak)) throw new ArgumentError(THROW_BAD_TWEAK);
  bool compressed = assumeCompression(_compressed, p);
  ECPoint pp = decodeFrom(p);
  if (_compare(tweak, zERO32) == 0) return getEncoded(pp, compressed);
  BigInt tt = fromBuffer(tweak);
  ECPoint qq = G * tt;
  ECPoint uu = pp + qq;
  if (uu.isInfinity) return null;
  return getEncoded(uu, compressed);
}
Uint8List privateAdd (Uint8List d,Uint8List tweak) {
  if (!isPrivate(d)) throw new ArgumentError(THROW_BAD_PRIVATE);
  if (!isOrderScalar(tweak)) throw new ArgumentError(THROW_BAD_TWEAK);
  BigInt dd = fromBuffer(d);
  BigInt tt = fromBuffer(tweak);
  Uint8List dt = toBuffer((dd + tt) % n);
  if (!isPrivate(dt)) return null;
  return dt;
}
Uint8List sign(Uint8List hash, Uint8List x) {
  if (!isScalar(hash)) throw new ArgumentError(THROW_BAD_HASH);
  if (!isPrivate(x)) throw new ArgumentError(THROW_BAD_PRIVATE);
  ECSignature sig = deterministicGenerateK(hash, x);
  Uint8List buffer = new Uint8List(64);
  buffer.setRange(0, 32, encodeBigInt(sig.r));
  var s;
  if (sig.s.compareTo(nDiv2) > 0) {
    s = n - sig.s;
  } else {
    s = sig.s;
  }
  buffer.setRange(32, 64, encodeBigInt(s));
  return buffer;
}
bool verify(Uint8List hash, Uint8List q, Uint8List signature) {
  if (!isScalar(hash)) throw new ArgumentError(THROW_BAD_HASH);
  if (!isPoint(q)) throw new ArgumentError(THROW_BAD_POINT);
  // 1.4.1 Enforce r and s are both integers in the interval [1, n − 1] (1, isSignature enforces '< n - 1')
  if (!isSignature(signature)) throw new ArgumentError(THROW_BAD_SIGNATURE);

  ECPoint Q = decodeFrom(q);
  BigInt r = fromBuffer(signature.sublist(0, 32));
  BigInt s = fromBuffer(signature.sublist(32, 64));

  final signer = new ECDSASigner(null, new HMac(new SHA256Digest(), 64));
  signer.init(false, new PublicKeyParameter(new ECPublicKey(Q, secp256k1)));
  return signer.verifySignature(hash, new ECSignature(r, s));
  /* STEP BY STEP
  // 1.4.1 Enforce r and s are both integers in the interval [1, n − 1] (2, enforces '> 0')
  if (r.compareTo(n) >= 0) return false;
  if (s.compareTo(n) >= 0) return false;

  // 1.4.2 H = Hash(M), already done by the user
  // 1.4.3 e = H
  BigInt e = fromBuffer(hash);

  BigInt sInv = s.modInverse(n);
  BigInt u1 = (e * sInv) % n;
  BigInt u2 = (r * sInv) % n;

  // 1.4.5 Compute R = (xR, yR)
  //               R = u1G + u2Q
  ECPoint R = G * u1 + Q * u2;

  // 1.4.5 (cont.) Enforce R is not at infinity
  if (R.isInfinity) return false;

  // 1.4.6 Convert the field element R.x to an integer
  BigInt xR = R.x.toBigInteger();

  // 1.4.7 Set v = xR mod n
  BigInt v = xR % n;

  // 1.4.8 If v = r, output "valid", and if v != r, output "invalid"
  return v.compareTo(r) == 0;
  */
}

BigInt fromBuffer(Uint8List d) { return decodeBigInt(d); }
Uint8List toBuffer(BigInt d) { return encodeBigInt(d); }
ECPoint decodeFrom(Uint8List P) { return secp256k1.curve.decodePoint(P); }
Uint8List getEncoded(ECPoint P, compressed) { return P.getEncoded(compressed); }

ECSignature deterministicGenerateK(Uint8List hash, Uint8List x) {
  final signer = new ECDSASigner(null, new HMac(new SHA256Digest(), 64));
  var pkp = new PrivateKeyParameter(new ECPrivateKey(decodeBigInt(x), secp256k1));
  signer.init(true, pkp);
//  signer.init(false, new PublicKeyParameter(new ECPublicKey(secp256k1.curve.decodePoint(x), secp256k1)));
  return signer.generateSignature(hash);
}



int _compare(Uint8List a, Uint8List b) {
  BigInt aa = fromBuffer(a);
  BigInt bb = fromBuffer(b);
  if (aa == bb) return 0;
  if (aa > bb) return 1;
  return -1;
}
