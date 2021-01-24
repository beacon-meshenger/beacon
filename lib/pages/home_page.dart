import 'package:chat/widgets/status.dart';
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
    return StreamBuilder<String>(
        stream: store.name(),
        builder: (context, snapshot) {
          final hasName = snapshot.hasData && snapshot.data.isNotEmpty;
          return Scaffold(
            appBar: AppBar(
              title: const Text("Beacon"),
              bottom: Status(false),
              actions: [
                if (hasName)
                  IconButton(
                    icon: Icon(Icons.qr_code),
                    tooltip: "Add Users",
                    onPressed: () {
                      Navigator.push(context,
                          new MaterialPageRoute(builder: (context) {
                        return QRCodePage();
                      }));
                    },
                  )
              ],
            ),
            body: hasName
                ? ChatListPage()
                : OnboardingPage(nameCallback: store.handleNameChange),
          );
        });
  }
}
