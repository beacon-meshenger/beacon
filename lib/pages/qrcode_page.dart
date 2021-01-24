import 'package:chat/widgets/qrcode.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../store.dart';

class QRCodePage extends StatefulWidget {
  @override
  _QRCodePageState createState() => _QRCodePageState();
}

class _QRCodePageState extends State<QRCodePage> {
  String publicKey;
  String scanned;

  @override
  void initState() {
    super.initState();
    _getPublicKey();

    scanned = '';
  }

  Future _getPublicKey() async {
    SharedPreferences _prefs = await SharedPreferences.getInstance();
    setState(() {
      publicKey = _prefs.getString('publicKey');
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Store store = Store.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Beacon"),
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (publicKey != null) QRCode(publicKey: publicKey),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          String scanVal = await qrScan(theme.accentColor);
          // -1 indicates scan was cancelled
          if (scanVal == "-1") return;
          var keys = store.prefs.getStringList('keys');
          if (keys == null) keys = [];
          if (!keys.contains(scanVal)) {
            keys.add(scanVal);
            store.prefs.setStringList('keys', keys);
          }
        },
        tooltip: 'Add user',
        child: const Icon(Icons.qr_code_scanner),
      ),
    );
  }
}
