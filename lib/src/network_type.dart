import 'dart:typed_data';

class Bip32Type {
  final int public;
  final int private;

  const Bip32Type({required this.public, required this.private});
}

class NetworkType {
  final String messagePrefix;
  final String bech32;
  final Bip32Type bip32;
  final int pubKeyHash;
  final int scriptHash;
  final int wif;

  const NetworkType({
    required this.messagePrefix,
    required this.bech32,
    required this.bip32,
    required this.pubKeyHash,
    required this.scriptHash,
    required this.wif,
  });
}

const NetworkType bitcoin = NetworkType(
  messagePrefix: '\x18Bitcoin Signed Message:\n',
  bech32: 'bc',
  bip32: Bip32Type(public: 0x0488b21e, private: 0x0488ade4),
  pubKeyHash: 0x00,
  scriptHash: 0x05,
  wif: 0x80,
);

const NetworkType testnet = NetworkType(
  messagePrefix: '\x18Bitcoin Signed Message:\n',
  bech32: 'tb',
  bip32: Bip32Type(public: 0x043587cf, private: 0x04358394),
  pubKeyHash: 0x6f,
  scriptHash: 0xc4,
  wif: 0xef,
);

Uint8List encodeVarint(int i) {
  if (i < 0xfd) return Uint8List.fromList([i]);
  if (i <= 0xffff) {
    return Uint8List.fromList([0xfd, i & 0xff, (i >> 8) & 0xff]);
  }
  if (i <= 0xffffffff) {
    return Uint8List.fromList(
        [0xfe, i & 0xff, (i >> 8) & 0xff, (i >> 16) & 0xff, (i >> 24) & 0xff]);
  }
  return Uint8List.fromList([
    0xff,
    i & 0xff,
    (i >> 8) & 0xff,
    (i >> 16) & 0xff,
    (i >> 24) & 0xff,
    (i >> 32) & 0xff,
    (i >> 40) & 0xff,
    (i >> 48) & 0xff,
    (i >> 56) & 0xff,
  ]);
}

int decodeVarint(Uint8List buffer, int offset) {
  final first = buffer[offset];
  if (first < 0xfd) return first;
  if (first == 0xfd) {
    return buffer[offset + 1] | (buffer[offset + 2] << 8);
  }
  if (first == 0xfe) {
    return buffer[offset + 1] |
        (buffer[offset + 2] << 8) |
        (buffer[offset + 3] << 16) |
        (buffer[offset + 4] << 24);
  }
  return buffer[offset + 1] |
      (buffer[offset + 2] << 8) |
      (buffer[offset + 3] << 16) |
      (buffer[offset + 4] << 24) |
      (buffer[offset + 5] << 32) |
      (buffer[offset + 6] << 40) |
      (buffer[offset + 7] << 48) |
      (buffer[offset + 8] << 56);
}

int varintLength(int i) {
  if (i < 0xfd) return 1;
  if (i <= 0xffff) return 3;
  if (i <= 0xffffffff) return 5;
  return 9;
}
