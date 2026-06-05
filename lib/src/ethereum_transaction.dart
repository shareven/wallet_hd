import 'dart:typed_data';

import 'package:wallet_hd/src/rlp.dart' as local_rlp;
import 'package:wallet_hd/src/wallet_config.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart' hide encode, uint8ListFromList;


class Etransaction {
  Transaction tx;
  int chainId;

  Etransaction(this.tx, this.chainId);
}

class EthereumTransaction {
  static Future<String> getEthAddress(String privateKeyHex)async{
    EthPrivateKey privateKey = EthPrivateKey.fromHex(privateKeyHex);
    EthereumAddress addr = privateKey.address;
    return addr.toString();
  }
  static Future<String?> signEthereumTransaction(
      EthPrivateKey privateKey, Etransaction transaction) async {
    final Uint8List unsignedTx = local_rlp.uint8ListFromList(local_rlp.encode(_encodeToRlp(
        transaction.tx,
        MsgSignature(BigInt.zero, BigInt.zero, transaction.chainId))));

    final signature = privateKey.signToEcSignature(unsignedTx,
        chainId: transaction.chainId);
    final Uint8List signedTx =
        local_rlp.uint8ListFromList(local_rlp.encode(_encodeToRlp(transaction.tx, signature)));

    String signedTxhex = bytesToHex(signedTx);

    return '0x' + signedTxhex;
  }

  static List<dynamic> _encodeToRlp(
      Transaction transaction, MsgSignature signature) {
    final list = <dynamic>[
      transaction.nonce,
      transaction.gasPrice?.getInWei ?? BigInt.zero,
      transaction.maxGas,
    ];

    if (transaction.to != null) {
      list.add(transaction.to!.addressBytes);
    } else {
      list.add('');
    }

    list..add(transaction.value?.getInWei ?? BigInt.zero)..add(transaction.data ?? Uint8List(0));

    list..add(signature.v)..add(signature.r)..add(signature.s);

    return list;
  }

  static Future<Etransaction?> createErc20Transaction(
      String from, String to, String value, String gasPrice, int nonce,
      {String type = 'USDT'}) async {
    if (WalletConfig.erc20Type.keys.contains(type)) {
      CoinInfo coinInfo = WalletConfig.erc20Type[type]!;

      String operationHex =
          '0xa9059cbb000000000000000000000000' + to.toLowerCase().substring(2);
      String valueHex =
          local_rlp.numPow2BigInt(double.parse(value), coinInfo.decimals).toRadixString(16);
      String tokenHex =
          ('0000000000000000000000000000000000000000000000000000000000000000' +
                  valueHex)
              .substring(valueHex.length);
      String dataHex = operationHex + tokenHex;


      Transaction transaction = Transaction(
          from: EthereumAddress.fromHex(from),
          to: EthereumAddress.fromHex(WalletConfig.erc20Type[type]!.address!),
          maxGas: coinInfo.gasLimit!,
          gasPrice: EtherAmount.inWei(BigInt.parse(gasPrice)),
          value: EtherAmount.zero(),
          data: hexToBytes(dataHex),
          nonce: nonce,);

      return Etransaction(transaction, coinInfo.network as int);
    } else {
      return null;
    }
  }

  static Future<Etransaction> createEthereumTransaction( String fromAddress,
      String toAddress, String amount, String gasPrice, int nonce) async {

      Transaction transaction = Transaction(
        from: EthereumAddress.fromHex(fromAddress),
        to: EthereumAddress.fromHex(toAddress),
        maxGas: 21000,
        gasPrice: EtherAmount.inWei(BigInt.parse(gasPrice)),
        value: EtherAmount.inWei(local_rlp.numPow2BigInt(double.parse(amount), 18)),
        data: Uint8List(0),
        nonce: nonce,
      );
      return Etransaction(transaction, 1);
  }
}
