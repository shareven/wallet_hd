library wallet_hd;

import 'package:bip39/bip39.dart' as bip39;
import 'package:wallet_hd/src/bitcoinTransaction.dart';
import 'package:wallet_hd/src/ethereumTransaction.dart';
import 'package:wallet_hd/src/wallet_config.dart';
import 'package:bitcoin_flutter/bitcoin_flutter.dart' as bitcoin_flutter;
import 'package:web3dart/web3dart.dart';

/// BTC转账
export 'package:wallet_hd/src/bitcoinTransaction.dart';

/// ETH转账
export 'package:wallet_hd/src/ethereumTransaction.dart';
export 'package:wallet_hd/src/rsaProxy.dart';

class WalletHd {
  /// 创建随机助记词 | Create Random Mnemonic
  static String createRandomMnemonic() {
    String randomMnemonic = bip39.generateMnemonic();
    return randomMnemonic;
  }

  /// 导入助记词，返回[btc地址 , eth地址] | Import mnemonic words and return [btc address, eth address]
  static Future<Map<String, String>> getAccountAddress(String mnemonic,
      {String derivePath}) async {
    String btcPath = (derivePath != null && derivePath.isNotEmpty)
        ? derivePath
        : WalletConfig.bitcoinType["BTC"].path;
    bitcoin_flutter.HDWallet hdWalletBtc =
        bitcoin_flutter.HDWallet.fromSeed(bip39.mnemonicToSeed(mnemonic))
            .derivePath(btcPath);
    String btcAddress = hdWalletBtc.address;

    String ethPath = (derivePath != null && derivePath.isNotEmpty)
        ? derivePath
        : WalletConfig.ethereumType["ETH"].path;
    EthPrivateKey ethPrivateKey =
        ethMnemonicToPrivateKey(mnemonic, derivePath: ethPath);
    EthereumAddress ethAddr = await ethPrivateKey.extractAddress();
    String ethAddress = ethAddr.toString();

    return {"BTC": btcAddress, "ETH": ethAddress};
  }

  /// ETH 导入助记词返回私钥 | ETH import mnemonic phrase and return private key
  static EthPrivateKey ethMnemonicToPrivateKey(String mnemonic,
      {String derivePath}) {
    String ethPath = (derivePath != null && derivePath.isNotEmpty)
        ? derivePath
        : WalletConfig.ethereumType["ETH"].path;
    bitcoin_flutter.HDWallet hdWalletEth =
        bitcoin_flutter.HDWallet.fromSeed(bip39.mnemonicToSeed(mnemonic))
            .derivePath(ethPath);

    String privateKey = hdWalletEth.privKey;

    EthPrivateKey ethPrivateKey = EthPrivateKey.fromHex(privateKey);
    return ethPrivateKey;
  }

  /// BTC 导入助记词返回私钥wif | BTC import mnemonic phrase and return private key wif
  static String btcMnemonicToPrivateKey(String mnemonic, {String derivePath}) {
    /// BTC 普通地址 | Ordinary address
    String btcPath = (derivePath != null && derivePath.isNotEmpty)
        ? derivePath
        : WalletConfig.bitcoinType["BTC"].path;
    bitcoin_flutter.HDWallet hdWalletBtc =
        bitcoin_flutter.HDWallet.fromSeed(bip39.mnemonicToSeed(mnemonic))
            .derivePath(btcPath);

    return hdWalletBtc.wif;
  }

  /// BTC转账 | BTC transfer
  static Future<String> transactionBTC(
    String mnemonic,
    String fromAddress,
    String toAddress,
    String amount,
    num fee,
    List<BitcoinIn> unspand,
  ) async {
    String privateKey = btcMnemonicToPrivateKey(mnemonic);

    Btransaction btransaction =
        await BitcoinTransaction.createBitcoinTransaction(
            fromAddress, toAddress, double.parse(amount), fee,
            unspends: unspand);

    String txPack = await BitcoinTransaction.signBitcoinTransaction(
        privateKey, btransaction);

    return txPack;
  }

  /// ETH转账 | ETH transfer
  static Future<String> transactionETH(
    String mnemonic,
    String fromAddress,
    String toAddress,
    String amount,
    String gasPrice,
    int nonce,
  ) async {
    EthPrivateKey ethPrivateKey = ethMnemonicToPrivateKey(mnemonic);

    Etransaction transaction =
        await EthereumTransaction.createEthereumTransaction(
            fromAddress, toAddress, amount, gasPrice, nonce);

    String txPack = await EthereumTransaction.signEthereumTransaction(
        ethPrivateKey, transaction);

    return txPack;
  }

  /// ERC20USDT转账 | ERC20USDT transfer
  static Future<String> transactionERC20USDT(
    String mnemonic,
    String fromAddress,
    String toAddress,
    String amount,
    String gasPrice,
    int nonce,
  ) async {
    EthPrivateKey ethPrivateKey = ethMnemonicToPrivateKey(mnemonic);

    Etransaction transaction = await EthereumTransaction.createErc20Transaction(
        fromAddress, toAddress, amount, gasPrice, nonce);

    String txPack = await EthereumTransaction.signEthereumTransaction(
        ethPrivateKey, transaction);

    return txPack;
  }
}
