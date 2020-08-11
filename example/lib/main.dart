import 'package:wallet_hd/wallet_hd.dart';

void main() async {
  String mnemonic = WalletHd.createRandomMnemonic();
  Map<String, String> mapAddr = await WalletHd.getAccountAddress(mnemonic);
  String btcAddr = mapAddr["BTC"];
  String ethAddr = mapAddr["ETH"];
  String toAddress = "input the to address ...";
  String amount = "0.1";
  String btcTxPack =
      await testTransactionBTC(mnemonic, btcAddr, toAddress, amount);
  String ethTxPack =
      await testTransactionETH(mnemonic, ethAddr, toAddress, amount);
  String erc20USDTTxPack =
      await testTransactionERC20USDT(mnemonic, ethAddr, toAddress, amount);
  print(btcTxPack);
  print(ethTxPack);
  print(erc20USDTTxPack);
}

Future testTransactionBTC(
  String mnemonic,
  String fromAddress,
  String toAddress,
  String amount,
) async {
  List unspandList = [
    {"txid": "0x12312313aaaaaaaaa", "output_no": 11, "value": "0.2323"},
    {"txid": "0x12312313bbbbbbbbb", "output_no": 12, "value": "0.2323"},
  ];
  List pendingList = [
    {"txid": "0x12312313aaaaaaaaa", "value": "0.2323"}
  ];
  double fee = 0.0002655;
  List handledUnspandList = unspandList;
  // 如果未确认交易列表不为空，则要从unspands list中去除待确认的交易 | If the list of unconfirmed transactions is not empty, remove the pending transactions from the unspands list
  if (pendingList.isNotEmpty) {
    pendingList.forEach((e) {
      handledUnspandList.removeWhere((x) => e["txid"] == x["txid"]);
    });
  }
  List<BitcoinIn> unspand = handledUnspandList
      .map(
          (e) => BitcoinIn(e["txid"], e["output_no"], double.parse(e["value"])))
      .toList();

  String txPack = await WalletHd.transactionBTC(
      mnemonic, fromAddress, toAddress, amount, fee, unspand);
  print("btc txPack");
  print(txPack);
}

Future testTransactionETH(
  String mnemonic,
  String fromAddress,
  String toAddress,
  String amount,
) async {
  String gasPrice = "113000000000";

  /// 新创建的账号初始none是-1 | the new account nonce is -1
  int nonce = -1;
  String txPack = await WalletHd.transactionETH(
      mnemonic, fromAddress, toAddress, amount, gasPrice, nonce);
  print("eth txPack");
  print(txPack);
}

Future testTransactionERC20USDT(
  String mnemonic,
  String fromAddress,
  String toAddress,
  String amount,
) async {
  String gasPrice = "113000000000";

  /// 新创建的账号初始none是-1 | the new account nonce is -1
  int nonce = -1;
  String txPack = await WalletHd.transactionERC20USDT(
      mnemonic, fromAddress, toAddress, amount, gasPrice, nonce);
  print("eth txPack");
  print(txPack);
}
