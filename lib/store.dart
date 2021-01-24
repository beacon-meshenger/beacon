import 'dart:async';
import 'dart:collection';

import 'package:path/path.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rxdart/rxdart.dart';

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

const _kPrefCurrentId = "me:id";
const _kPrefCurrentName = "me:name";
const _kPrefUserNamePrefix = "user:";

String _nameForId(SharedPreferences prefs, String userId) {
  final key = _kPrefUserNamePrefix + userId;
  if (prefs.containsKey(key)) {
    return prefs.getString(key);
  } else {
    return "Unknown";
  }
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
  String fromName;
  final String toId;
  final String data;

  Message({
    @required this.id,
    @required this.timestamp,
    @required this.fromId,
    this.fromName = "?",
    @required this.toId,
    @required this.data,
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
      fromName: _nameForId(prefs, map[_kMessageKeyFromId]),
      toId: map[_kMessageKeyToId],
      data: map[_kMessageKeyData],
    );
  }
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
    """);
    batch.execute("""
    CREATE INDEX ${_kMessageTable}_${_kMessageKeyTimestamp}_$_kMessageKeyChannelId
    ON $_kMessageTable ($_kMessageKeyTimestamp, $_kMessageKeyChannelId)
    """);
    await batch.commit(noResult: true);
  }

  static Future<Store> createStore() async {
    print("[Store] Creating store...");
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

    // TODO: maybe move key init to here to?

    final currentId = "UserMe"; // TODO: dynamic (store with `_kPrefCurrentId`)
    final currentName = prefs.containsKey(_kPrefCurrentName) ? prefs.getString(_kPrefCurrentName) : "";
    print("ID: $currentId Name: $currentName");

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
  final Map<String, ValueChanged<Message>> _newMessageCallbacks;
  final String _currentId;
  String _currentName;
  final BehaviorSubject<String> _currentNameSubject;

  Store._({
    @required this.db,
    @required this.prefs,
    @required Map<String, String> channels,
    @required String currentId,
    @required String currentName,
  })  : _channels = channels,
        _channelsSubject =
            BehaviorSubject.seeded(UnmodifiableMapView(channels)),
        _newMessageCallbacks = {},
        _currentId = currentId,
        _currentName = currentName,
        _currentNameSubject = BehaviorSubject.seeded(currentName);

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
      _newMessageCallbacks[channelId] = (newMessage) {
        messages.insert(0, newMessage);
        controller.add(UnmodifiableListView(messages));
      };
    }, onCancel: () async {
      print("[Store] Cancelling subscription to \"$channelId\" messages...");
      _newMessageCallbacks.remove(channelId);
      controller.close();
    });
    return controller.stream;
  }

  Stream<String> name() {
    print("[Store] Subscribing to name...");
    return _currentNameSubject.stream;
  }

  Future<void> handleMessage(Message message) async {
    final channelId = _channelId(
      fromId: message.fromId,
      toId: message.toId,
      currentId: _currentId,
    );
    print("[Store] Handling channel \"$channelId\" message ${message.id}...");
    _channels[channelId] = message.data;
    _channelsSubject.add(UnmodifiableMapView(this._channels));

    if (_newMessageCallbacks.containsKey(channelId)) {
      print("[Store] Notifying \"$channelId\" callback about ${message.id}...");
      _newMessageCallbacks[channelId](message);
    }

    await db.insert(_kMessageTable, message.toMap(currentId: _currentId));
  }

  Future<void> handleNameChange(String name) async {
    _currentName = name;
    _currentNameSubject.add(name);
    await prefs.setString(_kPrefCurrentName, name);
  }
}
