import 'package:bitcoin_flutter/bitcoin_flutter.dart' as bitcoin_flutter;

class WalletConfig {
  static final Map<String, CoinInfo> bitcoinType = {
    'BTC': CoinInfo("m/44'/0'/0'/0/0", bitcoin_flutter.bitcoin, 8),
  };
  static final Map<String, CoinInfo> omniType = {
    'USDT':
        CoinInfo("m/44'/0'/0'/0/0", bitcoin_flutter.bitcoin, 8, address: '31'),
    'TUSDT':
        CoinInfo("m/44'/0'/0'/0/1", bitcoin_flutter.testnet, 8, address: '2'),
  };
  static final Map<String, CoinInfo> ethereumType = {
    'ETH': CoinInfo("m/44'/60'/0'/0/0", 1, 18, gasLimit: 21000),
    'ETC': CoinInfo("m/44'/61'/0'/0/0", 1, 18, gasLimit: 21000),
  };
  static final Map<String, CoinInfo> erc20Type = {
    'USDT': CoinInfo("m/44'/60'/0'/0/0", 1, 6,
        address: '0xdAC17F958D2ee523a2206206994597C13D831ec7', gasLimit: 60000),
    'SIM': CoinInfo("m/44'/60'/0'/0/1", 4, 18,
        address: '0x454eb8D2994730a840A37e2A937e525916842Db8', gasLimit: 60000)
  };
}

class CoinInfo {
  final String path;
  final Object network; //NetworkType or int
  final int decimals;
  final String address;
  final int gasLimit;

  CoinInfo(this.path, this.network, this.decimals,
      {this.address, this.gasLimit});
}
