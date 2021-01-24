import 'package:chat/networking/mesh_client.dart';
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
        return RefreshIndicator(
          child: ListView.builder(
            itemBuilder: (context, i) {
              final channelId = list[i].key;
              final last = list[i].value;
              return ListTile(
                leading: Avatar(
                  user: channelId == ""
                      ? "📢"
                      : nameForChannelId(store.prefs, channelId)[0],
                  color: channelId == ""
                      ? theme.cardColor
                      : avatarColors[channelId.hashCode % avatarColors.length],
                  size: 40.0,
                ),
                title: Text(nameForChannelId(store.prefs, list[i].key)),
                subtitle: last == null
                    ? null
                    : Text(
                        last.startsWith("img:")
                            ? "📷 Image"
                            : last.startsWith("geo:")
                                ? "🌍 Shared Location"
                                : last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
          ),
          onRefresh: () async {
            MeshClient mesh = Store.of(context).mesh;

            // On network refresh, restart all network services
            // and remove all connected endpoints (forceably).
            await mesh.stopAllEndpoints();
            await mesh.restart();
          },
        );
      },
    );
  }
}
