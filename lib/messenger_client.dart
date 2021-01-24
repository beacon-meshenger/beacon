import 'dart:convert';
import 'dart:core';

import 'package:ble_app/mesh_client.dart';
import 'package:uuid/uuid.dart';
import 'dart:typed_data';

// These functions are implemented by blem
// void sendPayload(Uint8List payload, String destName) async {
//   print("Sending payload to $destName");
// }
//
// List<String> getConnectedClients() {
//   return ["client1", "client2"];
// }

////////////////////////////////////////

class Message {
  static final JsonEncoder JSON_ENCODER = new JsonEncoder();
  static final JsonDecoder JSON_DECODER = new JsonDecoder();

  final String uuid;

  final String srcName, dstName;
  final String srcNickname;

  final String type, contents;

  Message(this.uuid, this.srcName, this.dstName, this.srcNickname, this.type, this.contents);

  Message.fromJson(Map<String, dynamic> json)
    : uuid = json['uuid'],
      srcName = json['srcName'],
      dstName = json['dstName'],
      srcNickname = json['srcNickname'],
      type = json['type'],
      contents = json['contents'];

  Map<String, dynamic> toJson() =>
      {
        'uuid': uuid,
        'srcName': srcName,
        'dstName': dstName,
        'srcNickname': srcNickname,
        'type': type,
        'contents': contents,
      };

  Uint8List encode() =>
      Uint8List.fromList(utf8.encode(JSON_ENCODER.convert(toJson())));

  static Message decode(Uint8List encoded) =>
      Message.fromJson(JSON_DECODER.convert(utf8.decode(encoded)));
}

typedef OnMessageReceived = void Function(Message message);
class MessengerClient {

  static final Uuid UUID = Uuid();

  final String clientName, clientNickname;
  final MeshClient meshClient;

  final List<OnMessageReceived> onMessageReceivedCallbacks = new List<OnMessageReceived>();

  void registerOnMessageReceivedCallback(OnMessageReceived callback) {
    onMessageReceivedCallbacks.add(callback);
  }

  // TODO: Add a remove callback method

  MessengerClient(this.clientName, this.clientNickname, this.meshClient) {
    this.meshClient.registerOnPayloadReceivedCallback(onReceivePayload);
  }



  // Avoid repeatedly forwarding messages - this contains "UUID+connectedClientName"
  // TODO: Maybe make this expire somehow?
  Set<String> forwardingHistory = new Set();

  // Uint8List buildMessage(String src, String senderReadable, String dst, String messageType, String messageContents, String messageUUID) {
  //   Map<String, dynamic> payload = new Map();
  //   payload['src'] = src;
  //   payload['dst'] = dst;
  //   payload['senderName'] = senderReadable;
  //   payload['type'] = messageType;
  //   payload['data'] = messageContents;
  //   payload['UUID'] = messageUUID;
  //
  //   return Uint8List.fromList(utf8.encode(JSON_ENCODER.convert(payload)));
  // }
  //
  // Map<String, dynamic> decodeMessage(Uint8List payload) {
  //   return JSON_DECODER.convert(utf8.decode(payload));
  // }

  // Callback for blem.dart
  void onReceivePayload(Uint8List encoded, String sendingClientName) {
    Message message = Message.decode(encoded);

    print("onReceivePayload: ${ message.toString() }");

    // Map<String, dynamic> decoded = decodeMessage(encoded);

    if (message.dstName == clientName) {
      // This message is for us!!! No need to do any forwarding
      if (message.type != "DMAck") {
        sendDirectAck(message.srcName, message.uuid);
      }
      for (OnMessageReceived callback in onMessageReceivedCallbacks) {
        callback(message);
      }
    } else {
      if (meshClient.getClientIds().contains(message.dstName)) {
        // We have a direct connection :) Forward the message
        // TODO: Fix race if client disconnects here
        meshClient.sendPayload(message.dstName, encoded);

      } else {
        // We need to broadcast!

        // We never want to send it back to the client we received it from
        forwardingHistory.add(message.uuid + sendingClientName);

        // Probably also a race here
        for (String connectedClient in meshClient.getClientIds()) {
          String forwardingPath = message.uuid + connectedClient;
          // Only forward if we've never forwarded this message to this person before
          if (!forwardingHistory.contains(forwardingPath)) {
            meshClient.sendPayload(connectedClient, encoded);
            forwardingHistory.add(forwardingPath);
          }
        }
      }
    }
  }

  // Send a text message to another user "dst"
  void sendDirectTextMessage(String dstName, String contents) {
    String uuid = UUID.v4();

    Uint8List payload = new Message(uuid, clientName, dstName, clientNickname, "DMText", contents).encode();
    //
    // buildMessage(this.clientName, this.clientNickname, dst, "DMText", messageContents, messageUUID);
    onReceivePayload(payload, clientName);
  }

  void sendDirectAck(String dstName, String originalUUID) {
    String uuid = UUID.v4();

    Uint8List payload = new Message(uuid, clientName, dstName, clientNickname, "DMAck", originalUUID).encode();
    //
    // buildMessage(this.clientName, this.clientNickname, dst, "DMText", messageContents, messageUUID);
    onReceivePayload(payload, clientName);
  }

  // TODO: Sending delivery/read receipts

}