import 'dart:async';

import 'package:chat/locations.dart';
import 'package:chat/widgets/avatar.dart';
import 'package:chat/widgets/status.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../store.dart';

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
      _subscription = Store.of(context).messages(widget.channelId).listen(
        (messages) {
          setState(() => _messages = messages);
        },
      );
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
        title: Text(nameForChannelId(store.prefs, widget.channelId)),
        bottom: Status(nameForChannelId(store.prefs, widget.channelId) != "Nearby"),
      ),
      body: SafeArea(
        child: _MessageList(
          currentUserId: store.currentId,
          messages: _messages,
          channelId: widget.channelId,
          onMessageSend: (newMessage) {
            store.sendMessage(widget.channelId, newMessage);
          },
        ),
      ),
    );
  }
}

final _dateFormat = DateFormat("HH:mm, MMM d");

const _radius = Radius.circular(16.0);
const _sentRadius = BorderRadius.only(
  topLeft: _radius,
  topRight: _radius,
  bottomLeft: _radius,
);
const _receivedRadius = BorderRadius.only(
  topLeft: _radius,
  topRight: _radius,
  bottomRight: _radius,
);
const _timestampTextStyle = TextStyle(color: Colors.grey, fontSize: 12.0);

const _avatarColors = [
  Colors.deepOrange,
  Colors.amber,
  Colors.blueAccent,
  Colors.cyanAccent,
  Colors.deepPurple,
  Colors.greenAccent,
  Colors.pinkAccent,
  Colors.tealAccent,
];

class _Message extends StatelessWidget {
  final String currentUserId;
  final Message message;
  final Message nextMessage;
  final bool showFullName;

  _Message({
    Key key,
    @required this.currentUserId,
    @required this.message,
    this.nextMessage,
    this.showFullName = false,
  }) : super(key: key);

  Future<void> _launchMessage() async {
    if(await canLaunch(message.data)) {
      await launch(message.data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final ThemeData theme = Theme.of(context);
    final Store store = Store.of(context);
    final received = message.fromId != currentUserId;
    final textAlign = received ? TextAlign.left : TextAlign.right;
    final endOfThread = this.nextMessage?.fromId != this.message.fromId ||
        (this.nextMessage != null &&
            this.nextMessage.timestamp.difference(this.message.timestamp) >
                Duration(minutes: 1));

    final isLocation = message.data.startsWith("geo:");
    final fromName = message.fromName(store.prefs);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (received)
          if (endOfThread)
            Padding(
              padding: const EdgeInsets.only(bottom: 18.0),
              child: Avatar(
                user: fromName[0],
                color: _avatarColors[message.fromId.hashCode % _avatarColors.length],
              ),
            )
          else
            SizedBox(width: 32.0),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  received ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: !received && !message.acknowledged ? 0.5 : 1.0,
                  child: GestureDetector(
                    onTap: isLocation ? _launchMessage : null,
                    child: Container(
                      // margin: const EdgeInsets.symmetric(vertical: 4.0),
                      constraints: BoxConstraints(maxWidth: size.width * 2 / 3),
                      decoration: BoxDecoration(
                        color: received
                            ? (theme.brightness == Brightness.light
                                ? Colors.grey[200]
                                : Colors.grey[800])
                            : theme.accentColor,
                        borderRadius: received ? _receivedRadius : _sentRadius,
                      ),
                      padding: const EdgeInsets.all(8.0),
                      margin: EdgeInsets.only(
                        top: 4.0,
                        bottom: endOfThread ? 4.0 : 0.0,
                      ),
                      child: Text(
                        isLocation ? "🌍 Shared Location" : message.data,
                        style: TextStyle(
                          color: received ? null : Colors.white,
                          height: 1.4,
                        ),
                        textAlign: textAlign,
                      ),
                    ),
                  ),
                ),
                if (endOfThread)
                  Text(
                (showFullName ? "$fromName, " : "") +
                    _dateFormat.format(message.timestamp) +
                        (received
                            ? ""
                            : (", " +
                                (message.acknowledged ? "Received" : "Sent"))),
                    style: _timestampTextStyle,
                    textAlign: textAlign,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageList extends StatefulWidget {
  final String currentUserId;
  final List<Message> messages;
  final String channelId;
  final ValueChanged<String> onMessageSend;

  const _MessageList({
    Key key,
    @required this.currentUserId,
    @required this.messages,
    @required this.channelId,
    this.onMessageSend,
  }) : super(key: key);

  @override
  _MessageListState createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSendClick() {
    if (widget.onMessageSend != null) {
      widget.onMessageSend(_controller.text);
    }
    _controller.text = "";
  }

  void _onSendLocationClick() async {
    if (widget.onMessageSend != null) {
      final position = await getCurrentPosition();
      if (position != null) {
        widget.onMessageSend("geo:${position.latitude},${position.longitude}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // return Stack(
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemBuilder: (context, i) {
              return _Message(
                key: ValueKey(widget.messages[i].id),
                currentUserId: widget.currentUserId,
                message: widget.messages[i],
                nextMessage: i > 0 ? widget.messages[i - 1] : null,
                showFullName: widget.channelId.isEmpty,
              );
            },
            padding: const EdgeInsets.all(8.0),
            reverse: true,
            itemCount: widget.messages.length,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: theme.brightness == Brightness.light
                    ? Color(0x33AAAAAA)
                    : Color(0x33111111),
                offset: Offset(0, -4),
                blurRadius: 4.0,
              ),
            ],
          ),
          child: Material(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 10.0,
                          horizontal: 16.0,
                        ),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        hintText: "Message",
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send),
                    tooltip: "Send",
                    color: theme.accentColor,
                    onPressed: _controller.text.isEmpty ? null : _onSendClick,
                  ),
                  IconButton(
                    icon: Icon(Icons.location_on_outlined),
                    tooltip: "Send Location",
                    color: theme.accentColor,
                    onPressed: _onSendLocationClick,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
