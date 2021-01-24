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

const _kBluePrimary = Color(0xff2eb9ff);

class ChatApp extends StatelessWidget {
  final Store store;

  const ChatApp({Key key, this.store}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreProvider(
      store: store,
      child: MaterialApp(
        title: "Beacon",
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          // primarySwatch: Colors.deepOrange,
          // accentColor: Colors.deepOrange,
          // Generate with https://material.io/design/color/the-color-system.html#tools-for-picking-colors
          primarySwatch: MaterialColor(
            _kBluePrimary.value,
            <int, Color>{
              50: Color(0xffe2f6ff),
              100: Color(0xffb4e6ff),
              200: Color(0xff83d6ff),
              300: Color(0xff52c6ff),
              400: _kBluePrimary,
              500: Color(0xff17adfe),
              600: Color(0xff189eee),
              700: Color(0xff178bda),
              800: Color(0xff157ac6),
              900: Color(0xff165aa3),
            },
          ),
          accentColor: _kBluePrimary,
        ),
        home: HomePage(),
      ),
    );
  }
}
