import 'package:flutter/material.dart';

import '../store.dart';

class Status extends StatelessWidget implements PreferredSizeWidget {
  final bool encrypted;

  Status(this.encrypted);

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
              return Text("${(snapshot.hasData && snapshot.data > 0) ? "🟢" : "🔴"} Mesh Status: ${snapshot.hasData ? "connected to ${snapshot.data} phone${snapshot.data == 1 ? "" : "s"}" : "connecting..."} ${encrypted ? "\n🔒 Protected by end-to-end encryption" : ""}",
                style: const TextStyle(
                  fontSize: 14.0,
                  height: 1.5,
                ),
              );
            }
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => encrypted ? Size(0, 16.0 + 14.0 + 14.0 + 7.0) : Size(0, 16.0 + 14.0);
}
