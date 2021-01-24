import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:path/path.dart';
import 'package:flutter/material.dart';
import 'package:pointycastle/export.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rxdart/rxdart.dart';

import 'crypto.dart';

import 'networking/mesh_client.dart';
import 'networking/messenger_client.dart';

class StoreProvider extends InheritedWidget {
  final Store store;

  StoreProvider({
    Key key,
    this.store,
    Widget child,
  }) : super(key: key, child: child);

  static StoreProvider of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType();

  @override
  bool updateShouldNotify(covariant StoreProvider oldWidget) => false;
}

String _channelId({
  @required String fromId,
  @required String toId,
  @required String currentId,
}) {
  return toId == ""
      ? ""
      : fromId == currentId
          ? toId
          : fromId;
}

const _kPrefCurrentName = "me:name";
const _kPrefUserNamePrefix = "user:";

String nameForUserId(SharedPreferences prefs, String userId) {
  final key = _kPrefUserNamePrefix + userId;
  if (prefs.containsKey(key)) {
    return prefs.getString(key);
  } else {
    return "Unknown";
  }
}

String nameForChannelId(SharedPreferences prefs, String channelId) {
  return channelId == "" ? "Nearby" : nameForUserId(prefs, channelId);
}

String userIdFromPublicKey(String publicKey) {
  return base64
      .encode(new SHA256Digest().process(utf8.encode(publicKey)).sublist(0, 4));
}

const _kMessageTable = "message";
const _kMessageKeyId = "id";
const _kMessageKeyTimestamp = "timestamp";
const _kMessageKeyChannelId = "channelId";
const _kMessageKeyFromId = "fromId";
const _kMessageKeyToId = "toId";
const _kMessageKeyData = "data";

class Message {
  final String id;
  final DateTime timestamp;
  final String fromId;
  final String toId;
  final String data;
  bool acknowledged;

  Message({
    @required this.id,
    @required this.timestamp,
    @required this.fromId,
    @required this.toId,
    @required this.data,
    this.acknowledged = true,
  });

  Map<String, dynamic> toMap({@required String currentId}) {
    return {
      _kMessageKeyId: id,
      _kMessageKeyTimestamp: timestamp.millisecondsSinceEpoch ~/ 1000,
      _kMessageKeyChannelId: _channelId(
        fromId: fromId,
        toId: toId,
        currentId: currentId,
      ),
      _kMessageKeyFromId: fromId,
      _kMessageKeyToId: toId,
      _kMessageKeyData: data,
    };
  }

  factory Message.fromMap(
    Map<String, dynamic> map, {
    @required SharedPreferences prefs,
  }) {
    return Message(
      id: map[_kMessageKeyId],
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map[_kMessageKeyTimestamp] * 1000,
      ),
      fromId: map[_kMessageKeyFromId],
      toId: map[_kMessageKeyToId],
      data: map[_kMessageKeyData],
    );
  }

  fromName(SharedPreferences prefs) => nameForUserId(prefs, fromId);
}

class Store {
  static Store of(BuildContext context) => StoreProvider.of(context).store;

  static Future<void> _initDatabase(Database db, int version) async {
    print("[Store] Initialising database...");
    final batch = db.batch();
    batch.execute("""
    CREATE TABLE $_kMessageTable (
      $_kMessageKeyId TEXT PRIMARY KEY,
      $_kMessageKeyTimestamp INTEGER,
      $_kMessageKeyChannelId TEXT,
      $_kMessageKeyFromId TEXT,
      $_kMessageKeyToId TEXT,
      $_kMessageKeyData TEXT
    )
    """); // TODO: probably ought to store acknowledged in here, current just assume all stored messages acked
    batch.execute("""
    CREATE INDEX ${_kMessageTable}_${_kMessageKeyTimestamp}_$_kMessageKeyChannelId
    ON $_kMessageTable ($_kMessageKeyTimestamp, $_kMessageKeyChannelId)
    """);
    await batch.commit(noResult: true);
  }

  static Future<Store> createStore() async {
    print("[Store] Creating store...");

    // Initialise message database
    final path = join(await getDatabasesPath(), "store.db");
    final db = await openDatabase(path, version: 1, onCreate: _initDatabase);
    final prefs = await SharedPreferences.getInstance();
    print((await db.query(_kMessageTable)).join("\n"));
    final initialChannelsQuery =
        await db.rawQuery("""SELECT m1.channelId, m1.data
FROM message m1 LEFT JOIN message m2
ON (m1.channelId = m2.channelId AND m1.timestamp < m2.timestamp)
WHERE m2.timestamp IS NULL;""");
    final initialChannels = SplayTreeMap<String, String>.fromIterable(
      initialChannelsQuery,
      key: (map) => map["channelId"],
      value: (map) => map["data"],
    );
    initialChannels.putIfAbsent("", () => null);

    // Initialise key pair
    // Check if key pair exists, if not create
    if (!prefs.containsKey('publicKey') && !prefs.containsKey('privateKey')) {
      // Generate keys
      var keyPair = generateRSAkeyPair();

      var publicKeyBase64 = encodePublicKeyToPem(keyPair.publicKey);
      var privateKeyBase64 = encodePrivateKeyToPem(keyPair.privateKey);

      prefs.setString('publicKey', publicKeyBase64);
      prefs.setString('privateKey', privateKeyBase64);
    }

    final currentId = userIdFromPublicKey(prefs.getString("publicKey"));
    final currentName = prefs.containsKey(_kPrefCurrentName)
        ? prefs.getString(_kPrefCurrentName)
        : "";

    print("ID: $currentId Name: $currentName");

    // await prefs.setString(_kPrefUserNamePrefix + "User0", "Alice");
    // await prefs.setString(_kPrefUserNamePrefix + "User1", "Bob");
    // await prefs.setString(_kPrefUserNamePrefix + "User2", "Charlie");
    // await prefs.setString(_kPrefUserNamePrefix + "User3", "Daisy");
    // await prefs.setString(_kPrefUserNamePrefix + "User4", "Jenifer");

    return Store._(
      db: db,
      prefs: prefs,
      channels: initialChannels,
      currentId: currentId,
      currentName: currentName,
    );
  }

  final Database db;
  final SharedPreferences prefs;
  final Map<String, String> _channels;
  final BehaviorSubject<Map<String, String>> _channelsSubject;

  // Send <true, msg> for new message, <false, msg> for updated
  final Map<String, ValueChanged<MapEntry<bool, Message>>> _messageCallbacks;
  final String currentId;
  final BehaviorSubject<String> _currentNameSubject;
  final BehaviorSubject<int> _connectedDevicesSubject;

  MeshClient _mesh;
  MessengerClient _messenger;

  Store._({
    @required this.db,
    @required this.prefs,
    @required Map<String, String> channels,
    @required this.currentId,
    @required String currentName,
  })  : _channels = channels,
        _channelsSubject =
            BehaviorSubject.seeded(UnmodifiableMapView(channels)),
        _messageCallbacks = {},
        _currentNameSubject = BehaviorSubject.seeded(currentName),
        _connectedDevicesSubject = BehaviorSubject<int>.seeded(null) {
    _mesh = MeshClient(currentId, _onConnectedDevicesChanged);
    _mesh.initialise().then((_) => _mesh.start());
    _messenger = MessengerClient(currentId, currentName, _mesh);
    print("Set up messenger");

    _messenger.registerOnMessageReceivedCallback(_onMessageReceived);
  }
  
  void _onConnectedDevicesChanged(int devices) {
    _connectedDevicesSubject.add(devices);
  }

  Future<void> _onMessageReceived(DMMessage msg) async {
    print(msg.toString());
    if (msg.type == "DMAck") {
      await acknowledgeMessage(
        _channelId(
          fromId: msg.srcName,
          toId: msg.dstName,
          currentId: currentId,
        ),
        msg.contents,
      );
    } else {
      // if (msg.type == "BroadcastText") {
      await prefs.setString("user:${msg.srcName}", msg.srcNickname);
      // }
      await handleMessage(Message(
        id: msg.uuid,
        timestamp: DateTime.now(),
        fromId: msg.srcName,
        toId: msg.dstName,
        data: msg.contents,
      ));
    }
  }

  Stream<Map<String, String>> channels() {
    print("[Store] Subscribing to all channels...");
    return _channelsSubject.stream;
  }

  Stream<List<Message>> messages(String channelId) {
    print("[Store] Subscribing to \"$channelId\" messages...");
    List<Message> messages;
    StreamController<List<Message>> controller;
    controller = StreamController(onListen: () async {
      print("[Store] Listening to \"$channelId\" messages...");
      List<Map<String, dynamic>> maps = await db.query(
        _kMessageTable,
        where: "$_kMessageKeyChannelId = ?",
        whereArgs: [channelId],
        orderBy: "$_kMessageKeyTimestamp DESC",
      );
      messages = maps.map((map) => Message.fromMap(map, prefs: prefs)).toList();
      controller.add(UnmodifiableListView(messages));
      _messageCallbacks[channelId] = (MapEntry<bool, Message> entry) {
        final i =
            messages.indexWhere((element) => element.id == entry.value.id);
        if (entry.key /*create*/) {
          // Make sure we haven't inserted this message before
          if (i == -1) {
            messages.insert(0, entry.value);
          } else {
            print("[Store] Tried to insert message ${entry.value.id} again, ignoring...");
          }
        } else
        /*update*/ {
          // The old thing we are allowed to update is acknowledged
          messages[i].acknowledged = entry.value.acknowledged;
        }
        controller.add(UnmodifiableListView(messages));
      };
    }, onCancel: () async {
      print("[Store] Cancelling subscription to \"$channelId\" messages...");
      _messageCallbacks.remove(channelId);
      controller.close();
    });
    return controller.stream;
  }

  Stream<String> name() {
    print("[Store] Subscribing to name...");
    return _currentNameSubject.stream;
  }

  Stream<int> connectedDevices() {
    print("[Store] Subscribing to connected devices...");
    return _connectedDevicesSubject.stream;
  }

  Future<void> sendMessage(String channelId, String contents) async {
    String id;
    if (channelId.isEmpty) {
      id = _messenger.sendBroadcast(contents);
    } else {
      id = _messenger.sendDirectTextMessage(channelId, contents);
    }
    await handleMessage(Message(
      id: id,
      timestamp: DateTime.now(),
      fromId: currentId,
      toId: channelId,
      data: contents,
      acknowledged: false,
    ));
  }

  Future<void> handleMessage(Message message) async {
    final channelId = _channelId(
      fromId: message.fromId,
      toId: message.toId,
      currentId: currentId,
    );
    print("[Store] Handling channel \"$channelId\" message ${message.id}...");
    // Update last message for channel
    _channels[channelId] = message.data;
    _channelsSubject.add(UnmodifiableMapView(this._channels));

    if (_messageCallbacks.containsKey(channelId)) {
      print("[Store] Notifying \"$channelId\" callback about ${message.id}...");
      _messageCallbacks[channelId](MapEntry(true /*create*/, message));
    }

    try {
      await db.insert(_kMessageTable, message.toMap(currentId: currentId));
    } catch (e) {
      print("[Store] Error inserting into database: $e");
    }
  }

  Future<void> acknowledgeMessage(String channelId, String messageId) async {
    if (_messageCallbacks.containsKey(channelId)) {
      print(
          "[Store] Notifying \"$channelId\" callback about $messageId acknowledgement...");
      _messageCallbacks[channelId](MapEntry(
        false /*update*/,
        Message(
          id: messageId,
          acknowledged: true,
          // These will be ignored in the update (this is pretty horrible, but it works)
          timestamp: null,
          fromId: null,
          toId: null,
          data: null,
        ),
      ));
    }

    // TODO: if we are going to be persisting acknowledgement (as opposed to just defaulting to true), store in db here
  }

  Future<void> handleNameChange(String name) async {
    _messenger.clientNickname = name;
    _currentNameSubject.add(name);
    await prefs.setString(_kPrefCurrentName, name);
  }
}
