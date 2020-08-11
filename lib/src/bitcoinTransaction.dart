import 'dart:typed_data';

import 'package:bitcoin_flutter/bitcoin_flutter.dart';
import 'package:wallet_hd/src/p2sh.dart';
import 'package:wallet_hd/src/rlp.dart';
import 'package:wallet_hd/src/wallet_config.dart';
import 'package:web3dart/crypto.dart';
import 'package:bech32/bech32.dart';
import 'package:bs58check/bs58check.dart' as bs58check;

class BitcoinIn {
  String txHash;
  int outputNo;
  num value;

  BitcoinIn(this.txHash, this.outputNo, this.value);
}

class Btransaction {
  TransactionBuilder txb;
  NetworkType network;

  Btransaction(this.txb, this.network);
}

class BitcoinTransaction {
  static Future<String> signBitcoinTransaction(
      String privateKey, Btransaction transaction) async {
    if (transaction != null) {
      try {
        ECPair ecPair =
            ECPair.fromWIF(privateKey, network: transaction.network);
        transaction.txb.inputs.forEach((element) {
          int index = transaction.txb.inputs.indexOf(element);
          transaction.txb.sign(vin: index, keyPair: ecPair);
        });
        Transaction tx = transaction.txb.buildIncomplete();
        String hex = tx.toHex();
        return hex;
      } catch (e) {
        print('BitcoinTransaction.signBitcoinTransaction error : $e');
      }
    } else {
      print(
          'BitcoinTransaction.signBitcoinTransaction error : transaction is null.');
    }
    return null;
  }

  // 6a = 106 OP_RETURN
  // 14 = 20
  // 6f6d6e69 = omni
  static const _omni = '6a146f6d6e69';
  static final BigInt dirt = BigInt.from(546);
  static String _fillLengthWith(String s,
      {int length = 16, String char = '0'}) {
    if (s == null) return '';
    if (s.length >= length) return s.substring(0, length);
    return (char * length + s).substring(s.length);
  }

  static String _createOmniPayload(BigInt value, int contract) {
    String type = contract.toRadixString(16);
    String valueHex = value.toRadixString(16);
    String payload = _omni + _fillLengthWith(type) + _fillLengthWith(valueHex);
    return payload;
  }

  static Future<Btransaction> createBitcoinTransaction(
      String from, String to, num value, num fee,
      {String type = 'BTC', List<BitcoinIn> unspends}) async {
    if (WalletConfig.bitcoinType.keys.contains(type) &&
        unspends != null &&
        unspends.isNotEmpty) {
      CoinInfo coinInfo = WalletConfig.bitcoinType[type];

      final txb = new TransactionBuilder(network: coinInfo.network);
      BigInt coinFee = numPow2BigInt(fee, coinInfo.decimals);
      BigInt coinValue = numPow2BigInt(value, coinInfo.decimals);

      BigInt amount = BigInt.zero;
      unspends.forEach((element) {
        amount += numPow2BigInt(element.value, coinInfo.decimals);
        txb.addInput(element.txHash, element.outputNo);
      });
      BigInt change = amount - coinValue - coinFee;
      print("amount:$amount");
      print("coinValue:$coinValue");
      print("coinFee:$coinFee");
      print("change:$change");
      if (change < BigInt.zero) {
        print('Amount is not enough.');
      } else {
        if (change >= dirt) {
          Uint8List fromAddr = addressToOutputScript(from, coinInfo.network);
          // 找零给自己 | Get change for yourself
          txb.addOutput(fromAddr, change.toInt());
        }

        Uint8List toAddr = addressToOutputScript(to, coinInfo.network);
        print(toAddr);
        // 转给别人 | Transfer to others
        txb.addOutput(toAddr, coinValue.toInt());
        return Btransaction(txb, coinInfo.network);
      }
    }
    return null;
  }

  static Future<Btransaction> createOmniTransaction(
      String from, String to, num value, num fee,
      {String type = 'USDT', List<BitcoinIn> unspends}) async {
    if (WalletConfig.omniType.keys.contains(type)) {
      CoinInfo coinInfo = WalletConfig.omniType[type];
      try {
        final txb = new TransactionBuilder(network: coinInfo.network);
        const int decimals = 8;
        BigInt coinFee = numPow2BigInt(fee, decimals);

        BigInt amount = BigInt.zero;
        unspends.forEach((element) {
          amount += numPow2BigInt(element.value, decimals);
          txb.addInput(element.txHash, element.outputNo);
        });
        BigInt change = amount - dirt - coinFee;
        if (change < BigInt.zero) {
          print('Amount is not enough.');
        } else {
          if (change >= dirt) {
            Uint8List fromAddr = addressToOutputScript(from, coinInfo.network);
            // 找零给自己 | Get change for yourself
            txb.addOutput(fromAddr, change.toInt());
          }

          Uint8List toAddr = addressToOutputScript(to, coinInfo.network);
          print("toAddr");
          print(toAddr);
          txb.addOutput(toAddr, dirt.toInt());

          BigInt bigValue = numPow2BigInt(value, coinInfo.decimals);
          int contract = num.parse(coinInfo.address).toInt();
          String payload = _createOmniPayload(bigValue, contract);
          print("payload");
          print(payload);

          txb.addOutput(hexToBytes(payload), 0);

          return Btransaction(txb, coinInfo.network);
        }
      } catch (e) {
        print('BitcoinTransaction.createOmniTransaction error : $e');
      }
    }
    return null;
  }

  static Uint8List addressToOutputScript(String address, [NetworkType nw]) {
    NetworkType network = nw ?? bitcoin;
    var decodeBase58;
    var decodeBech32;
    try {
      decodeBase58 = bs58check.decode(address);
    } catch (err) {}
    if (decodeBase58 != null) {
      if (decodeBase58[0] == network.pubKeyHash) {
        P2PKH p2pkh = new P2PKH(
            data: new PaymentData(address: address), network: network);
        return p2pkh.data.output;
      }
      if (decodeBase58[0] == network.scriptHash) {
        P2SH p2sh =
            new P2SH(data: new PaymentData(address: address), network: network);
        return p2sh.data.output;
      }
    } else {
      try {
        decodeBech32 = segwit.decode(address);
      } catch (err) {}
      if (decodeBech32 != null) {
        if (network.bech32 != decodeBech32.hrp)
          throw new ArgumentError('Invalid prefix or Network mismatch');
        if (decodeBech32.version != 0)
          throw new ArgumentError('Invalid address version');
        P2WPKH p2wpkh = new P2WPKH(
            data: new PaymentData(address: address), network: network);
        return p2wpkh.data.output;
      }
    }
    throw new ArgumentError(address + ' has no matching Script');
  }
}
