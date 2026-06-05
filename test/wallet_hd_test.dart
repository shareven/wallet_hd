import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_hd/wallet_hd.dart';
import 'package:wallet_hd/src/rlp.dart' as rlp;
import 'package:wallet_hd/src/script.dart' as bscript;
import 'package:wallet_hd/src/op.dart';
import 'package:wallet_hd/src/ecurve.dart';
import 'package:wallet_hd/src/crypto.dart';
import 'package:wallet_hd/src/handle_big_int.dart';
import 'package:hex/hex.dart';

void main() {
  // ========== 基础功能测试 ==========

  test('createRandomMnemonic returns 12-word mnemonic', () {
    final mnemonic = WalletHd.createRandomMnemonic();
    final words = mnemonic.split(' ');
    expect(words.length, 12);
  });

  test('getAccountAddress returns BTC and ETH addresses', () async {
    final mnemonic =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    final addresses = await WalletHd.getAccountAddress(mnemonic);

    expect(addresses.containsKey('BTC'), isTrue);
    expect(addresses.containsKey('ETH'), isTrue);
    expect(addresses['BTC']!, isNotEmpty);
    expect(addresses['ETH']!, isNotEmpty);
    expect(addresses['ETH']!.startsWith('0x'), isTrue);
  });

  test('btcMnemonicToPrivateKey returns valid WIF', () {
    final mnemonic =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    final wif = WalletHd.btcMnemonicToPrivateKey(mnemonic);
    expect(wif, isNotEmpty);
    expect(wif.startsWith('5') || wif.startsWith('K') || wif.startsWith('L'),
        isTrue);
  });

  test('ethMnemonicToPrivateKey returns valid hex private key', () {
    final mnemonic =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    final key = WalletHd.ethMnemonicToPrivateKey(mnemonic);
    expect(key, isNotNull);
  });

  test('getAccountAddress with custom derivePath', () async {
    final mnemonic =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    final addresses = await WalletHd.getAccountAddress(mnemonic,
        derivePath: "m/44'/0'/0'/0/1");
    expect(addresses['BTC']!, isNotEmpty);
    expect(addresses['ETH']!, isNotEmpty);
  });

  // ========== numPow2BigInt 测试 ==========

  test('numPow2BigInt handles integer value', () {
    expect(rlp.numPow2BigInt(10, 8), BigInt.from(1000000000));
  });

  test('numPow2BigInt handles decimal value', () {
    expect(rlp.numPow2BigInt(0.1, 8), BigInt.from(10000000));
  });

  test('numPow2BigInt handles small decimal', () {
    expect(rlp.numPow2BigInt(0.0002655, 8), BigInt.from(26550));
  });

  test('numPow2BigInt handles zero', () {
    expect(rlp.numPow2BigInt(0, 8), BigInt.zero);
  });

  test('numPow2BigInt handles large value', () {
    expect(rlp.numPow2BigInt(0.2323, 8), BigInt.from(23230000));
  });

  test('numPow2BigInt handles 18 decimals (ETH)', () {
    expect(rlp.numPow2BigInt(1.5, 18),
        BigInt.parse('1500000000000000000'));
  });

  // ========== 编解码测试 ==========

  test('encodeBigInt and decodeBigInt round-trip', () {
    final values = [
      BigInt.zero,
      BigInt.one,
      BigInt.from(255),
      BigInt.from(256),
      BigInt.from(0xffff),
      BigInt.parse('12345678901234567890'),
    ];
    for (final v in values) {
      final encoded = encodeBigInt(v);
      final decoded = decodeBigInt(encoded);
      expect(decoded, v);
    }
  });

  test('hex encoding round-trip', () {
    final data = Uint8List.fromList([0, 1, 255, 128, 64, 32]);
    final hex = HEX.encode(data);
    final decoded = HEX.decode(hex) as Uint8List;
    expect(decoded, data);
  });

  // ========== 加密函数测试 ==========

  test('hash160 produces 20 bytes', () {
    final data = Uint8List.fromList([1, 2, 3, 4, 5]);
    final result = hash160(data);
    expect(result.length, 20);
  });

  test('hash256 produces 32 bytes', () {
    final data = Uint8List.fromList([1, 2, 3, 4, 5]);
    final result = hash256(data);
    expect(result.length, 32);
  });

  test('hmacSHA512 produces 64 bytes', () {
    final key = Uint8List.fromList([1, 2, 3]);
    final data = Uint8List.fromList([4, 5, 6]);
    final result = hmacSHA512(key, data);
    expect(result.length, 64);
  });

  // ========== isPoint / isPrivate 测试 ==========

  test('isPrivate returns true for valid private key', () {
    final key = Uint8List(32);
    key[31] = 1;
    expect(isPrivate(key), isTrue);
  });

  test('isPrivate returns false for zero', () {
    final key = Uint8List(32);
    expect(isPrivate(key), isFalse);
  });

  test('isPrivate returns false for wrong length', () {
    expect(isPrivate(Uint8List(16)), isFalse);
    expect(isPrivate(Uint8List(33)), isFalse);
  });

  // ========== 脚本编译测试 ==========

  test('compile and decompile round-trip', () {
    final chunks = <dynamic>[
      OPS['OP_DUP'],
      OPS['OP_HASH160'],
      Uint8List.fromList(List.filled(20, 0xab)),
      OPS['OP_EQUALVERIFY'],
      OPS['OP_CHECKSIG'],
    ];
    final compiled = bscript.compile(chunks);
    final decompiled = bscript.decompile(compiled);
    expect(decompiled, isNotNull);
    expect(decompiled!.length, chunks.length);
  });

  test('compile P2PKH output', () {
    final hash = Uint8List.fromList(List.filled(20, 0xab));
    final script = bscript.compile([
      OPS['OP_DUP'],
      OPS['OP_HASH160'],
      hash,
      OPS['OP_EQUALVERIFY'],
      OPS['OP_CHECKSIG'],
    ]);
    expect(script.length, 25);
    expect(script[0], OPS['OP_DUP']);
    expect(script[1], OPS['OP_HASH160']);
    expect(script[2], 0x14);
    expect(script[3], 0xab);
    expect(script[23], 0x88); // OP_EQUALVERIFY
    expect(script[24], 0xac); // OP_CHECKSIG
  });

  test('compile P2SH output', () {
    final hash = Uint8List.fromList(List.filled(20, 0xcd));
    final script = bscript.compile([
      OPS['OP_HASH160'],
      hash,
      OPS['OP_EQUAL'],
    ]);
    expect(script.length, 23);
  });

  // ========== 地址一致性测试 ==========

  test('same mnemonic always produces same BTC address', () async {
    final mnemonic =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    final addr1 = await WalletHd.getAccountAddress(mnemonic);
    final addr2 = await WalletHd.getAccountAddress(mnemonic);
    expect(addr1['BTC'], addr2['BTC']);
    expect(addr1['ETH'], addr2['ETH']);
  });

  test('different mnemonics produce different addresses', () async {
    final addr1 = await WalletHd.getAccountAddress(
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about');
    final addr2 = await WalletHd.getAccountAddress(
        'ability ability ability ability ability ability ability ability ability ability ability about');
    expect(addr1['BTC'], isNot(addr2['BTC']));
  });

  // ========== 签名/验证测试 ==========

  test('sign and verify round-trip', () {
    final key = Uint8List(32);
    key[31] = 1;
    final hash = Uint8List(32);
    hash[0] = 0xaa;
    hash[15] = 0xbb;
    hash[31] = 0xcc;

    final signature = sign(hash, key);
    expect(signature.length, 64);

    final pubkey = pointFromScalar(key, true);
    expect(pubkey, isNotNull);
    expect(pubkey!.length, 33);

    final verified = verify(hash, pubkey, signature);
    expect(verified, isTrue);
  });

  test('verify rejects wrong key', () {
    final key1 = Uint8List(32);
    key1[31] = 1;
    final key2 = Uint8List(32);
    key2[31] = 2;
    final hash = Uint8List(32);
    hash[0] = 0xaa;

    final signature = sign(hash, key1);
    final pubkey2 = pointFromScalar(key2, true);

    final verified = verify(hash, pubkey2!, signature);
    expect(verified, isFalse);
  });

  // ========== DER 编码测试 ==========

  test('encodeSignature produces valid DER', () {
    final sig = Uint8List(64);
    sig[31] = 0x12;
    sig[63] = 0x34;
    final derSig = bscript.encodeSignature(sig, 0x01);
    expect(derSig.length, 9);
    expect(derSig[0], 0x30); // DER SEQUENCE
    expect(derSig[derSig.length - 1], 0x01); // SIGHASH_ALL
  });

  // ========== 曲线运算测试 ==========

  test('pointFromScalar produces compress pubkey', () {
    final key = Uint8List(32);
    key[31] = 1;
    final pubkey = pointFromScalar(key, true);
    expect(pubkey, isNotNull);
    expect(pubkey!.length, 33);
    expect(pubkey[0] == 0x02 || pubkey[0] == 0x03, isTrue);
  });

  test('pointFromScalar produces uncompressed pubkey', () {
    final key = Uint8List(32);
    key[31] = 1;
    final pubkey = pointFromScalar(key, false);
    expect(pubkey, isNotNull);
    expect(pubkey!.length, 65);
    expect(pubkey[0], 0x04);
  });

  test('isPoint validates compressed pubkey', () {
    final key = Uint8List(32);
    key[31] = 1;
    final pubkey = pointFromScalar(key, true)!;
    expect(isPoint(pubkey), isTrue);
  });

  test('isPoint validates uncompressed pubkey', () {
    final key = Uint8List(32);
    key[31] = 1;
    final pubkey = pointFromScalar(key, false)!;
    expect(isPoint(pubkey), isTrue);
  });

  test('pointAddScalar handles zero tweak', () {
    final key = Uint8List(32);
    key[31] = 1;
    final pubkey = pointFromScalar(key, true)!;
    final tweak = Uint8List(32);
    final result = pointAddScalar(pubkey, tweak, true);
    expect(result, isNotNull);
  });

  test('privateAdd produces valid private key', () {
    final key = Uint8List(32);
    key[31] = 1;
    final tweak = Uint8List(32);
    tweak[31] = 2;
    final result = privateAdd(key, tweak);
    expect(result, isNotNull);
    expect(isPrivate(result!), isTrue);
  });
}
