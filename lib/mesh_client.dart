import 'dart:typed_data';

import 'package:logger/logger.dart';
import 'package:nearby_connections/nearby_connections.dart';

import 'bi_map.dart';


typedef OnPayloadReceived = void Function(Uint8List payload);
class MeshClient {

  final Logger LOG  = Logger();
  final Strategy STRATEGY = Strategy.P2P_CLUSTER;



  final String _clientId;
  final OnPayloadReceived _onPayloadReceived;

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
              print("reeeeeeeeeee");
              await Nearby().requestConnection(
                _clientId, id,
                onConnectionInitiated: _onConnectionInitiated,
                onConnectionResult: _onConnectionResult,
                onDisconnected: _onDisconnected,
              );
            } catch (e) {
              LOG.e("Request error: ${e.toString()}");
            }
          }
        },
        onEndpointLost: _onDisconnected
    );
  }

  void _onDisconnected(String id) {
    _clientIds.remove(id);
    _sessionIdClientIdMap.remove(id);
    LOG.i("Disconnected: $id");
  }

  void _onConnectionResult(String id, Status status) {
    if (status == Status.CONNECTED) {
      LOG.i("Connected: $id");
      _clientIds.add(_sessionIdClientIdMap[id]);
    } else {
      _sessionIdClientIdMap.remove(id);
    }
  }

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    LOG.i("Connection initiated: $id, ${ info.authenticationToken }, ${ info.endpointName }, ${ info.isIncomingConnection.toString() }");

    _sessionIdClientIdMap[id] = info.endpointName;
    Nearby().acceptConnection(
        id,
        onPayLoadRecieved: (endId, payload) async {
          if (payload.type == PayloadType.BYTES)
            _onPayloadReceived(payload.bytes);
        },
    );
  }

  List<String> getClientIds() {
    return _clientIds;
  }

  MeshClient(String this._clientId, OnPayloadReceived this._onPayloadReceived) {
    Logger.level = Level.info;

    _enableLocation().then((bool success) async {
      if (success) await _initService();
      LOG.i("Service started");
    });
  }

  void sendPayload(String id, Uint8List payload) {
    if (_clientIds.contains(id)) Nearby().sendBytesPayload(_sessionIdClientIdMap.inverse(id), payload);
    else LOG.i("Send Payload Error. $id not in _clientIds");
  }

  void broadcastPayload(Uint8List payload) {
    for (String id in _clientIds) sendPayload(id, payload);
  }

}