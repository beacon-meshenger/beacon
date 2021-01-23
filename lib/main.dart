import 'dart:async';

import "package:flutter/material.dart";

import 'avatar.dart';
import 'messages.dart';
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

  // This widget is the root of your application.
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
          // primarySwatch: Colors.pink,
          // accentColor: Colors.pink,
        ),
        // theme: ThemeData.light(),
        // theme: ThemeData(
        //   primarySwatch: Colors.blue,
        // ),
        home: HomePage(),
      ),
    );
  }
}

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
      ),
      body: StreamBuilder<Map<String, String>>(
          stream: store.channels(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return Container();
            final list = snapshot.data.entries.toList();
            return ListView.builder(
              itemBuilder: (context, i) {
                return ListTile(
                  leading: Avatar(
                    user: list[i].key == "" ? "@" : list[i].key,
                    size: 40.0,
                  ),
                  title: Text(list[i].key == "" ? "Everyone" : list[i].key),
                  subtitle: Text(list[i].value),
                  onTap: () {
                    Navigator.push(context,
                        new MaterialPageRoute(builder: (context) {
                      return new ChatPage(channelId: list[i].key);
                    }));
                  },
                );
              },
              itemCount: list.length,
            );
          }),
    );
  }
}

class ChatPage extends StatefulWidget {
  final String channelId;

  const ChatPage({Key key, this.channelId}) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<Message> _messages = [];
  StreamSubscription<List<Message>> _subscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_subscription == null) {
      _subscription =
          Store.of(context).messages(widget.channelId).listen((messages) {
        setState(() => _messages = messages);
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = Store.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Beacon"),
      ),
      body: SafeArea(
        child: MessageList(
          currentUserId: "UserMe", // TODO: dynamic from store probably
          messages: _messages,
          onMessageSend: (newMessage) {
            store.handleMessage(Message(
              id: DateTime.now().toString(), // TODO: use id instead
              timestamp: DateTime.now(),
              fromId: "UserMe",
              toId: widget.channelId,
              data: newMessage,
            ));
          },
        ),
      ),
    );
  }
}
