import 'package:flutter/material.dart';

import '../store.dart';
import 'chat_list_page.dart';
import 'onboarding_page.dart';
import 'qrcode_page.dart';

class HomePage extends StatefulWidget {
  HomePage({Key key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    final store = Store.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Beacon"),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code),
            onPressed: () {
              Navigator.push(context, new MaterialPageRoute(builder: (context) {
                return QRCodePage();
              }));
            },
          )
        ],
      ),
      body: StreamBuilder<String>(
        stream: store.name(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data.isNotEmpty) {
            return ChatListPage();
          } else {
            return OnboardingPage(nameCallback: store.handleNameChange);
          }
        },
      ),
    );
  }
}