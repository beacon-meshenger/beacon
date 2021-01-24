import 'package:flutter/material.dart';

import '../store.dart';

class Status extends StatelessWidget implements PreferredSizeWidget {
  @override
  Widget build(BuildContext context) {
    final store = Store.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, bottom: 16.0, right: 16.0),
      child: Row(
        children: [
          StreamBuilder<int>(
            stream: store.connectedDevices(),
            builder: (context, snapshot) {
              return Text(
                "Mesh Status: ${snapshot.hasData ? "connected to ${snapshot.data} device${snapshot.data == 1 ? "" : "s"}" : "connecting..."} ",
                style: const TextStyle(
                  fontSize: 14.0,
                  height: 1.0,
                ),
              );
            }
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size(0, 16.0 + 14.0);
}
