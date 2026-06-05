library wallet_hd;

import 'package:bip39/bip39.dart' as bip39;
import 'package:wallet_hd/src/bitcoin_transaction.dart';
import 'package:wallet_hd/src/ethereum_transaction.dart';
import 'package:wallet_hd/src/wallet_config.dart';
import 'package:wallet_hd/src/bip32_hd.dart';
import 'package:web3dart/web3dart.dart';

export 'package:wallet_hd/src/bitcoin_transaction.dart';
export 'package:wallet_hd/src/ethereum_transaction.dart';
export 'package:wallet_hd/src/rsa_proxy.dart';

class WalletHd {
  static String createRandomMnemonic() {
    return bip39.generateMnemonic();
  }

  static Future<Map<String, String>> getAccountAddress(String mnemonic,
      {String? derivePath}) async {
    String btcPath = (derivePath != null && derivePath.isNotEmpty)
        ? derivePath
        : WalletConfig.bitcoinType["BTC"]!.path;
    HDWallet hdWalletBtc =
        HDWallet.fromSeed(bip39.mnemonicToSeed(mnemonic))
            .derivePath(btcPath);
    String btcAddress = hdWalletBtc.address;

    String ethPath = (derivePath != null && derivePath.isNotEmpty)
        ? derivePath
        : WalletConfig.ethereumType["ETH"]!.path;
    EthPrivateKey ethPrivateKey =
        ethMnemonicToPrivateKey(mnemonic, derivePath: ethPath);
    EthereumAddress ethAddr = ethPrivateKey.address;
    String ethAddress = ethAddr.toString();

    return {"BTC": btcAddress, "ETH": ethAddress};
  }

  static EthPrivateKey ethMnemonicToPrivateKey(String mnemonic,
      {String? derivePath}) {
    String ethPath = (derivePath != null && derivePath.isNotEmpty)
        ? derivePath
        : WalletConfig.ethereumType["ETH"]!.path;
    HDWallet hdWalletEth =
        HDWallet.fromSeed(bip39.mnemonicToSeed(mnemonic))
            .derivePath(ethPath);

    String privateKey = hdWalletEth.privKey;

    return EthPrivateKey.fromHex(privateKey);
  }

  static String btcMnemonicToPrivateKey(String mnemonic, {String? derivePath}) {
    String btcPath = (derivePath != null && derivePath.isNotEmpty)
        ? derivePath
        : WalletConfig.bitcoinType["BTC"]!.path;
    HDWallet hdWalletBtc =
        HDWallet.fromSeed(bip39.mnemonicToSeed(mnemonic))
            .derivePath(btcPath);

    return hdWalletBtc.wif;
  }

  static Future<String?> transactionBTC(
    String mnemonic,
    String fromAddress,
    String toAddress,
    String amount,
    num fee,
    List<BitcoinIn> unspand,
  ) async {
    String privateKey = btcMnemonicToPrivateKey(mnemonic);

    Btransaction? btransaction =
        await BitcoinTransaction.createBitcoinTransaction(
            fromAddress, toAddress, double.parse(amount), fee,
            unspends: unspand);

    if (btransaction == null) return null;

    return BitcoinTransaction.signBitcoinTransaction(
        privateKey, btransaction);
  }

  static Future<String?> transactionETH(
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

    return EthereumTransaction.signEthereumTransaction(
        ethPrivateKey, transaction);
  }

  static Future<String?> transactionERC20USDT(
    String mnemonic,
    String fromAddress,
    String toAddress,
    String amount,
    String gasPrice,
    int nonce,
  ) async {
    EthPrivateKey ethPrivateKey = ethMnemonicToPrivateKey(mnemonic);

    Etransaction? transaction = await EthereumTransaction.createErc20Transaction(
        fromAddress, toAddress, amount, gasPrice, nonce);

    if (transaction == null) return null;

    return EthereumTransaction.signEthereumTransaction(
        ethPrivateKey, transaction);
  }
}
