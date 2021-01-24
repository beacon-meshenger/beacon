import 'package:chat/widgets/avatar.dart';
import 'package:flutter/material.dart';

import '../store.dart';
import 'chat_page.dart';

class ChatListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = Store.of(context);
    return StreamBuilder<Map<String, String>>(
      stream: store.channels(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Container();
        final list = snapshot.data.entries.toList();
        return ListView.builder(
          itemBuilder: (context, i) {
            final last = list[i].value;
            return ListTile(
              leading: Avatar(
                user: list[i].key == "" ? "📢" : list[i].key[0],
                color: list[i].key == "" ? theme.cardColor : theme.accentColor,
                size: 40.0,
              ),
              title: Text(nameForChannelId(store.prefs, list[i].key)),
              subtitle: last == null
                  ? null
                  : Text(last.startsWith("geo:") ? "Shared Location" : last),
              onTap: () {
                Navigator.push(context, new MaterialPageRoute(
                  builder: (context) {
                    return ChatPage(channelId: list[i].key);
                  },
                ));
              },
            );
          },
          itemCount: list.length,
        );
      },
    );
  }
}
