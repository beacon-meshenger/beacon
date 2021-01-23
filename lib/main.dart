// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.


import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'dart:math';
import 'package:nearby_connections/nearby_connections.dart';

void main() {
  runApp(BeaconApp());
}
class BeaconApp extends StatefulWidget {
  @override
  _BeaconAppState createState() => _BeaconAppState();
}

class _BeaconAppState extends State<BeaconApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text("Beacon App"),
        ),
        body: Body(),
      ),
    );
  }
}


class Body extends StatefulWidget {
  @override
  _BodyState createState() => _BodyState();
}

class _BodyState extends State<Body> {

  static String getRandString(int len) {
    var random = Random.secure();
    var values = List<int>.generate(len, (i) =>  random.nextInt(255));
    return base64UrlEncode(values);
  }

  final Strategy strategy = Strategy.P2P_STAR;
  final String userName = getRandString(8);

  String cId = "0";

  void notify(Object obj) {
    Scaffold.of(context).showSnackBar(SnackBar(content: Text(obj.toString())));
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView(
          children: <Widget>[
            Text("Permissions"),
            Wrap(
              children: <Widget>[
                RaisedButton(
                  child: Text("checkLocationPermission"),
                  onPressed: () async {
                    if (await Nearby().checkLocationPermission())
                      notify("Location permissions granted :)");
                    else
                      notify("Location permissions not granted :(");
                  },
                ),
                RaisedButton(
                  child: Text("askLocationPermission"),
                  onPressed: () async {
                    if (await Nearby().askLocationPermission())
                      notify("Location permissions granted :)");
                    else
                      notify("Location permissions not granted :(");
                  },
                ),
                RaisedButton(
                  child: Text("checkExternalStoragePermission"),
                  onPressed: () async {
                    if (await Nearby().checkExternalStoragePermission())
                      notify("External storage permissions granted :)");
                    else
                      notify("External storage not permissions granted :(");
                  },
                ),
                RaisedButton(
                  child: Text("askExternalStoragePermission"),
                  onPressed: () {
                    Nearby().askExternalStoragePermission();
                  },
                ),
              ],
            ),
            Divider(),
            Text("Location Enabled"),
            Wrap(
              children: <Widget>[
                RaisedButton(
                  child: Text("checkLocationEnabled"),
                  onPressed: () async {
                    if (await Nearby().checkLocationEnabled())
                      notify("Location is on :)");
                    else
                      notify("Location if off :(");
                  },
                ),
                RaisedButton(
                  child: Text("enableLocationServices"),
                  onPressed: () async {
                    if (await Nearby().enableLocationServices())
                      notify("Location service enabled :)");
                    else
                      notify("Enabling location service failed :(");
                  },
                ),
              ],
            ),
            Divider(),
            Text("User Name: " + userName),
            Wrap(
              children: <Widget>[
                RaisedButton(
                  child: Text("Start Advertising"),
                  onPressed: () async {
                    try {
                      bool a = await Nearby().startAdvertising(
                        userName,
                        strategy,
                        onConnectionInitiated: onConnectionInit,
                        onConnectionResult: (id, status) {
                          notify(status.toString());
                        },
                        onDisconnected: (id) {
                          notify("Disconnected: $id");
                        },
                      );
                      notify("ADVERTISING: ${a.toString()}");
                    } catch (exception) {
                      notify(exception.toString());
                    }
                  },
                ),
                RaisedButton(
                  child: Text("Stop Advertising"),
                  onPressed: () async {
                    await Nearby().stopAdvertising();
                  },
                ),
              ],
            ),
            Wrap(
              children: <Widget>[
                RaisedButton(
                  child: Text("Start Discovery"),
                  onPressed: () async {
                    try {
                      print("Trying to run Nearby().startDiscovery");
                      bool a = await Nearby().startDiscovery(
                        userName,
                        strategy,
                        onEndpointFound: (id, name, serviceId) {
                          print("Endpoint found: $id $name $serviceId");

                          // show sheet automatically to request connection
                          showModalBottomSheet(
                            context: context,
                            builder: (builder) {
                              return Center(
                                child: Column(
                                  children: <Widget>[
                                    Text("id: " + id),
                                    Text("Name: " + name),
                                    Text("ServiceId: " + serviceId),
                                    RaisedButton(
                                      child: Text("Request Connection"),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        Nearby().requestConnection(
                                          userName,
                                          id,
                                          onConnectionInitiated: (id, info) {
                                            onConnectionInit(id, info);
                                          },
                                          onConnectionResult: (id, status) {
                                            notify(status.toString());
                                          },
                                          onDisconnected: (id) {
                                            notify(id.toString());
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        onEndpointLost: (id) {
                          notify("Lost Endpoint:" + id);
                        },
                      );
                      notify("DISCOVERING: " + a.toString());
                    } catch (e) {
                      notify(e);
                    }
                  },
                ),
                RaisedButton(
                  child: Text("Stop Discovery"),
                  onPressed: () async {
                    await Nearby().stopDiscovery();
                  },
                ),
              ],
            ),
            RaisedButton(
              child: Text("Stop All Endpoints"),
              onPressed: () async {
                await Nearby().stopAllEndpoints();
              },
            ),
            Divider(),
            Text(
              "Sending Data",
            ),
            RaisedButton(
              child: Text("Send Random Bytes Payload"),
              onPressed: () async {
                String a = Random().nextInt(100).toString();
                notify("Sending $a to $cId");
                Nearby().sendBytesPayload(cId, Uint8List.fromList(a.codeUnits));
              },
            ),
          ],
        ),
      ),
    );
  }

  void onConnectionInit(String id, ConnectionInfo info) {
    showModalBottomSheet(
      context: context,
      builder: (builder) {
        return Center(
          child: Column(
            children: <Widget>[
              Text("id: " + id),
              Text("Token: " + info.authenticationToken),
              Text("Name" + info.endpointName),
              Text("Incoming: " + info.isIncomingConnection.toString()),
              RaisedButton(
                child: Text("Accept Connection"),
                onPressed: () {
                  Navigator.pop(context);
                  cId = id;
                  Nearby().acceptConnection(
                    id,
                    onPayLoadRecieved: (endid, payload) async {
                      if (payload.type == PayloadType.BYTES) {
                        String str = String.fromCharCodes(payload.bytes);
                        notify(endid + ": " + str);
                      }
                    },
                    onPayloadTransferUpdate: (endid, payloadTransferUpdate) {
                    },
                  );
                },
              ),
              RaisedButton(
                child: Text("Reject Connection"),
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await Nearby().rejectConnection(id);
                  } catch (e) {
                    notify(e);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

}
