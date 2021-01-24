import "package:flutter/material.dart";

import 'pages/home_page.dart';
import 'store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await Store.createStore();

  // for (int i = 0; i < 5; i++) {
  //   await store.handleMessage(Message(
  //     id: "message_${i}_2",
  //     timestamp: DateTime.now().add(Duration(seconds: i)),
  //     fromId: "User$i",
  //     toId: "UserMe",
  //     data: "Second Message from $i",
  //   ));
  //   await store.handleMessage(Message(
  //     id: "broadcast_message_${i}_2",
  //     timestamp: DateTime.now().add(Duration(seconds: i)),
  //     fromId: "User$i",
  //     toId: "",
  //     data: "Second Broadcast Message from $i"
  //   ));
  // }

  runApp(ChatApp(store: store));
}

class ChatApp extends StatelessWidget {
  final Store store;

  const ChatApp({Key key, this.store}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreProvider(
      store: store,
      child: MaterialApp(
        title: "Beacon",
        theme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.deepOrange,
          accentColor: Colors.deepOrange,
        ),
        home: HomePage(),
      ),
    );
  }
}
