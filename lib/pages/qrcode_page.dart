import 'package:chat/widgets/qrcode.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../crypto.dart';

import '../store.dart';

class QRCodePage extends StatefulWidget {
  @override
  _QRCodePageState createState() => _QRCodePageState();
}

class _QRCodePageState extends State<QRCodePage> {
  String publicKey;
  String scanned;
  String data;
  String addedUser;
  GlobalKey<ScaffoldState> scaffoldState;

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
      key: scaffoldState,
      appBar: AppBar(
        title: const Text("Add Users"),
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (publicKey != null) Container( child: StreamBuilder<String>(
                  stream: store.name(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data.isNotEmpty) {
                      final encoder = new JsonEncoder();
                      String data = encoder.convert({
                        'name': snapshot.data,
                        'publicKey': publicKey
                      });

                      return QRCode(data: data);
                    } else {
                      return Text("Name loading...");
                    }
                  },
                )
              ),

              Container(
                padding: const EdgeInsets.all(16.0),
                child: StreamBuilder<String>(
                    stream: store.name(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data.isNotEmpty) {
                        return Text(
                          snapshot.data + "'s QR Code",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                        );
                      } else {
                        return Text("Name loading...");
                    }
                  },
                ),
              ),
              Text(
                "Let your friends scan this to add you!",
                style: TextStyle(fontSize: 16),
              )
            ],
          ),
        ),
      ),
      floatingActionButton: StreamBuilder<String>(
        stream: store.name(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data.isNotEmpty) {
            return FloatingActionButton(
              onPressed: () async {
                String scanVal = await qrScan(theme.accentColor);
                // -1 indicates scan was cancelled
                if (scanVal == "-1") return;
                // Decode json
                final decoder = new JsonDecoder();
                var decodedScanval = decoder.convert(scanVal);

                print(decodedScanval['name']);
                print(decodedScanval['publicKey']);

                if (decodedScanval['name'].toString().isNotEmpty && decodedScanval['publicKey'].toString().isNotEmpty) {
                  // save name
                  await store.prefs.setString('user:${userIdFromPublicKey(decodedScanval['publicKey'])}', decodedScanval['name']);

                  var keys = store.prefs.getStringList('keys');
                  if (keys == null) keys = [];
                  if (!keys.contains(decodedScanval['publicKey'])) {
                    keys.add(decodedScanval['publicKey']);
                    await store.prefs.setStringList('keys', keys);
                  }
                }
                // TODO add send code
                final encoder = new JsonEncoder();

                store.messenger.sendKey(
                    userIdFromPublicKey(decodedScanval['publicKey']),
                    parsePublicKeyFromPem(decodedScanval['publicKey']),
                    encoder.convert({
                      'name': snapshot.data,
                      'publicKey': publicKey
                    })
                );


                // Successfully added
                scaffoldState.currentState.showSnackBar(new SnackBar(content: new Text(decodedScanval['name'])));
              },

              tooltip: 'Add user',
              child: const Icon(Icons.qr_code_scanner),
            );
          } else {
            return FloatingActionButton();
          }
        },
      ),
    );
  }
}
