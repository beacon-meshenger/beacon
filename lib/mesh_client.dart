import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:nearby_connections/nearby_connections.dart';

import 'bi_map.dart';


typedef OnPayloadReceived = void Function(Uint8List payload, String clientId);
class MeshClient {

  final Logger LOG  = Logger();
  final Strategy STRATEGY = Strategy.P2P_CLUSTER;

  final String _clientId;
  final List<OnPayloadReceived> _onPayloadReceivedCallbacks = new List<OnPayloadReceived>();

  final BiMap<String, String> _sessionIdClientIdMap = new BiMap<String, String>();
  final List<String> _clientIds = new List<String>();


  Future<bool> _enableLocation() async {
    bool locationPermissionGranted = await Nearby().askLocationPermission();
    bool locationServicesEnabled = await Nearby().enableLocationServices();
    return locationPermissionGranted && locationServicesEnabled;
  }

  Future<void> _initService() async {
    await Nearby().startAdvertising(
        _clientId, STRATEGY,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected
    );


    await Nearby().startDiscovery(
        _clientId, STRATEGY,
        onEndpointFound: (id, name, serviceId) async {
          if (_clientId.compareTo(name) > 0) {
            LOG.i("Requesting connection to endpoint $name from client $_clientId");
            try {
              await Nearby().requestConnection(
                _clientId, id,
                onConnectionInitiated: _onConnectionInitiated,
                onConnectionResult: _onConnectionResult,
                onDisconnected: _onDisconnected,
              );
            } catch (e) {
              LOG.e("Connection Request error: ${e.toString()}");
            }
          }
        },
        onEndpointLost: _onDisconnected
    );
  }

  void _onDisconnected(String id) {
    _clientIds.remove(_sessionIdClientIdMap[id]);
    _sessionIdClientIdMap.remove(id);
    LOG.i("Disconnected: $id");
  }

  void _onConnectionResult(String id, Status status) {
    if (status == Status.CONNECTED) {
      LOG.i("Connected: $id");
      _clientIds.add(_sessionIdClientIdMap[id]);
    } else {
      _onDisconnected(id);
    }
  }

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    LOG.i("Connection initiated: $id, ${ info.authenticationToken }, ${ info.endpointName }, ${ info.isIncomingConnection.toString() }");

    _sessionIdClientIdMap[id] = info.endpointName;
    Nearby().acceptConnection(
        id,
        onPayLoadRecieved: (endId, payload) async {
          if (payload.type == PayloadType.BYTES) {
            for (OnPayloadReceived callback in _onPayloadReceivedCallbacks) {
              callback(payload.bytes, _sessionIdClientIdMap[endId]);
            }
          }
        },
    );
  }

  List<String> getClientIds() {
    return _clientIds;
  }



  MeshClient(String this._clientId) {
    Logger.level = Level.info;

    _enableLocation().then((bool success) async {
      if (success) await _initService();
      LOG.i("Service started");
    });
  }

  void registerOnPayloadReceivedCallback(OnPayloadReceived callback) {
    _onPayloadReceivedCallbacks.add(callback);
  }

  // TODO: Add remove function for callbacks

  Future<void> sendPayload(String id, Uint8List payload) async {
    try {
      if (_clientIds.contains(id)) await Nearby().sendBytesPayload(_sessionIdClientIdMap.inverse(id), payload);
      else LOG.e("Send Payload Error. $id not in _clientIds");
    } catch (e) {
      LOG.e("Connection request error: ${e.toString()}");
    }
  }

  Future<void> broadcastPayload(Uint8List payload) async {
    for (String id in _clientIds) await sendPayload(id, payload);
  }

}