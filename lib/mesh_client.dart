import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:nearby_connections/nearby_connections.dart';

import 'bi_map.dart';


typedef OnPayLoadReceived = void Function(String clientName, Uint8List payload);

abstract class MeshClient {
  final Logger LOG  = Logger();
  final Strategy STRATEGY = Strategy.P2P_CLUSTER;

  final String _clientName;

  MeshClient(this._clientName) {
    Logger.level = Level.info;
  }

  // Initializing the permissions and requirements for the device

  Future<bool> _hasPermissions() async {
    return await Nearby().checkLocationPermission() && await Nearby().checkLocationEnabled();
  }

  Future<bool> _requestPermissions() async {
    return await Nearby().askLocationPermission() && await Nearby().enableLocationServices();
  }

  Future<void> initialise() async {
    if (!await _hasPermissions()) {
      if (!await _requestPermissions()) {
        throw "Unable to start mesh client.";
      }
    }
  }

  // Managing the Nearby Protocols

  Future<void> restart() async {
    await stop();
    await start();
  }

  Future<void> start() async {
    await startDiscovery();
    await startAdvertising();
  }

  Future<void> stop() async {
    await stopDiscovery();
    await stopAdvertising();
  }


  // Protocol Specific asynchronous implementations

  Future<void> startAdvertising();
  Future<void> startDiscovery();

  Future<void> stopDiscovery() async {
    await Nearby().stopDiscovery();
  }

  Future<void> stopAdvertising() async {
    await Nearby().stopAdvertising();
  }

  // A mapping from so-called 'endpointIds' to clientNames (or endpointNames)
  final BiMap<String, String> idNameMap = new BiMap();


  // Payload Methods

  final List<OnPayLoadReceived> _onPayLoadReceivedCallbacks = new List();

  Future<void> _onPayLoadReceived(String endpointId, Payload payload) async {
    if (payload.type == PayloadType.BYTES) {
      for (OnPayLoadReceived callback in _onPayLoadReceivedCallbacks) {
        callback(idNameMap[endpointId], payload.bytes);
      }
    }
  }

  // Payload Callback Register (and Deregister) Methods

  void registerOnPayLoadReceivedCallback(OnPayLoadReceived callback) {
    _onPayLoadReceivedCallbacks.add(callback);
  }

  // TODO: Add remove function for callbacks

  // Payload Sending Methods

  Future<void> sendPayload(String clientName, Uint8List payload) async {
    try {
      await Nearby().sendBytesPayload(idNameMap.inverse(clientName), payload);
    } catch (e) {
      LOG.e("Connection request error: ${e.toString()}");
    }
  }

  //
  // Future<void> broadcastPayload(Uint8List payload) async {
  //   for (String id in _clientIds) await sendPayload(id, payload);
  // }


  List<String> getClientNames() {
    print("client names: ${idNameMap.values}");
    return idNameMap.values.toList();
  }

}


class MeshClientSnake extends MeshClient {

  // bool isDiscovering = false;
  // bool isAdvertising = false;

  MeshClientSnake(String clientName) : super(clientName);

  // Snake-like (ish) implementation.
  // The head is advertising and discovering.
  // Body parts are advertising (according to google this is more efficiency,
  // discovery leads to thrashing? saw this on SO page, cannot remember which one lol)

  // Let us consider the following arbitrary disconnected graph:
  //
  //    A/D(N1)         A/D(N2)          A/D(N3)
  //
  // Suppose, non-deterministically, node N2 discovers the
  // endpoint N1 (which simply requires N1 to be in mode A)
  // and requests a connection.

  // N2 then transitions to state A (stopDiscovery), yielding the graph
  //
  //  A/D(N1) <----- A(N2)          A/D(N3)
  //
  // Yeilding a chain. This eventually results in something like:
  //
  // A/D(N1) <-- A(N2) <-- A(N3) <-- ... <-- A(N_M)
  //              ^         ^                   ^
  //              |         |                   |
  //              .         .                   .

  // On a partition, we restart the nearby connection (this hopefully should
  // restart the service and start looking for devices), thus attempting to
  // heal the partition

  // Each advertising node has a maximum connection limit of 3 (to ensure
  // stability of the connections while advertising).

  // To ensure DAGs, we have the following total ordering on node names:
  //
  // N1 > N2 > N3 > ... > N_M


  // Protocol Methods

  Future<void> _onDisconnected(String endpointId) async {
    // Due to chain, we have a partition or we've "lost the endpoint", whatever
    // that means. Either way, its bad... very bad! AAAAAAAAAAAAAAA
    LOG.w("Disconnected from an endpoint: $endpointId. Restarting service...");
    idNameMap.remove(endpointId);
    await restart();
  }


  @override
  Future<void> startDiscovery() async {
    try {
      await Nearby().startDiscovery(
        _clientName, STRATEGY,
        onEndpointFound: (endpointId, endpointName, serviceId) async {
          LOG.i("Endpoint found: ${endpointName}");

          // If we've connected to this endpoint, ignore.
          if (idNameMap.containsKey(endpointId)) return;

          // This prevents other nodes attempting to request a connection
          // while we attempt to request a connection
          LOG.i("Stopping advertising...");
          await stopAdvertising();

          LOG.i("Requesting connection ");
          await Nearby().requestConnection(
            _clientName, endpointId,
            onConnectionInitiated: (endpointId, info) async {
              LOG.i("Connection Initiated with ${endpointId}.");
              idNameMap[endpointId] = endpointName;
              Nearby().acceptConnection(
                  endpointId, onPayLoadRecieved: _onPayLoadReceived);
            },
            onConnectionResult: (endpointId, status) async {
              if (status == Status.CONNECTED) {
                // We have successfully connected to an endpoint
                // Thus we need to disable discovery and re-enable advertising
                LOG.i("Connected: ${endpointId}, ${idNameMap[endpointId]}");
                await stopDiscovery();

                // Advertising is restarted below: (degenerate case)
              } else {
                // If we have failed to connect, then remove the endpoint
                // entry
                LOG.w(
                    "Failed to connect: ${endpointId}, ${idNameMap[endpointId]}");
                idNameMap.remove(endpointId);
              }

              // We have failed to connect (or we have connected).
              // Either way, we must enable advertising
              await startAdvertising();
            },
            onDisconnected: _onDisconnected,
          );
        },
        onEndpointLost: _onDisconnected,
      );
    } on PlatformException catch (e) {
      LOG.e("Discovery Error: ${e.toString()}");
    }
  }

  @override
  Future<void> startAdvertising() async {
    try {
      await Nearby().startAdvertising(
          _clientName, STRATEGY,
          onConnectionInitiated: (endpointId, ConnectionInfo info) async {
            LOG.i("Connection Initiated with ${endpointId}.");
            // Perform comparison on info.endpointName to ensure acyclic property
            if (_clientName.compareTo(info.endpointName) > 0) {
              LOG.i("Accepting connection :)");
              // Yay! We have N1 > N2. Accept the connection :)
              idNameMap[endpointId] = info.endpointName;
              Nearby().acceptConnection(
                  endpointId, onPayLoadRecieved: _onPayLoadReceived);
            } else {
              LOG.w("Rejecting connection :(");
              // Noooooo. We cannot connect at this end of the chain :(
              // Hopefully? the device will try to connect at the head :) (who knows...)
              Nearby().rejectConnection(endpointId);
            }
          },
          onConnectionResult: (endpointId, status) async {
            if (status == Status.CONNECTED) {
              // We've successfully connected :)
              LOG.i("Connected: ${endpointId}, ${idNameMap[endpointId]}");
            } else {
              // We failed to connect :(
              // Remove the entry from nodes.
              LOG.w(
                  "Failed to connect: ${endpointId}, ${idNameMap[endpointId]}");
              idNameMap.remove(endpointId);
            }
          },
          onDisconnected: _onDisconnected
      );
    } on PlatformException catch (e) {
      LOG.e("Advertising Error: ${e.toString()}");
    }
  }


}
//
// // MeshClientRandom
//
//
// class MeshClientRandom extends MeshClient {
//
//   MeshClientRandom(String clientName) : super(clientName);
//
//   // State
//   bool isConnected = false;
//   bool isDiscovering = false;
//   bool isAdvertising = false;
//
//
//
//   Future<void> _onDisconnected(String endpointId) async {
//     // Something bad has happened. In the context of the random protocol, the
//     // semantics of a disconnection is undefined (or I'm too stupid to figure it out rn tbh)
//     // So Panic!
//     LOG.w("Disconnected from an endpoint: $endpointId. Restarting service...");
//     idNameMap.remove(endpointId);
//     await restart();
//   }
//
//   Future<void> _onConnectionInitiated(String endpointId, ConnectionInfo info) {
//     LOG.i("Connection Initiated with ${endpointId}, ${ info.endpointName }.");
//
//     // Simply accept the connection :)
//     idNameMap[endpointId] = info.endpointName;
//     Nearby().acceptConnection(endpointId, onPayLoadRecieved: _onPayLoadReceived);
//   }
//
//   Future<void> _toggleService() {
//     // According to obsecure SO response, avg connection time is 2 ~ 7 seconds.
//     // So we switch every 7 to 15 seconds
//     new Future.delayed(Duration(seconds: new Random().nextInt(8) + 7), () async {
//       await stop();
//
//       // Toggle
//       if (isDiscovering) {
//         await startAdvertising();
//       } else {
//         await startDiscovery();
//       }
//
//       // Recursively call
//       _toggleService();
//     });
//   }
//
//   Future<void> _onConnectionResult(String endpointId, Status status) async {
//     if (status == Status.CONNECTED) {
//       LOG.i("Connected: ${endpointId}, ${idNameMap[endpointId]}");
//
//       if (!isConnected) {
//         LOG.i("Initial connection! Employing non-deterministic smart shit!");
//         // Yay! This is the first time (or what appears to the first time)
//         // that our device has connected to a mesh network.
//
//         // We now stop all services (discovery and advertising),
//         // randomly select a service, and then toggle in future
//         await stop();
//         if (new Random().nextInt(1) == 0) {
//           // Assign 0.5 probability mass to each option
//           await startDiscovery();
//         } else {
//           await startAdvertising();
//         }
//
//         // Now enter a asynchronous
//         _toggleService();
//       }
//     } else {
//       LOG.w("Failed to connect: ${endpointId}, ${idNameMap[endpointId]}");
//       idNameMap.remove(endpointId);
//
//       // In the case of discovery -> advertiser, we need to
//       // re-enable advertising
//       await startAdvertising();
//     }
//   }
//
//   @override
//   Future<void> startDiscovery() async {
//     if (!isDiscovering) return;
//
//     await Nearby().startDiscovery(
//       _clientName, STRATEGY,
//       onEndpointFound: (endpointId, endpointName, serviceId) async {
//         LOG.i("Endpoint found: ${endpointName}");
//
//         // This prevents other nodes attempting to request a connection
//         // while we attempt to request a connection
//         LOG.i("Stopping advertising...");
//         await stopAdvertising();
//
//         // Request a connection
//         await Nearby().requestConnection(
//             _clientName, endpointId,
//             onConnectionInitiated: _onConnectionInitiated,
//             onConnectionResult: _onConnectionResult,
//             onDisconnected: _onDisconnected,
//         );
//       },
//       onEndpointLost: _onDisconnected,
//     );
//
//     isDiscovering = true;
//   }
//
//   @override
//   Future<void> startAdvertising() async {
//     if (isAdvertising) return;
//
//     await Nearby().startAdvertising(
//         _clientName, STRATEGY,
//         onConnectionInitiated: _onConnectionInitiated,
//         onConnectionResult: _onConnectionResult,
//         onDisconnected: _onDisconnected
//     );
//
//     isAdvertising = true;
//   }
//
// }

//
// class MeshClient {
//
//   // final Logger LOG = Logger();
//   // final Strategy STRATEGY = Strategy.P2P_CLUSTER;
//   //
//   // final String _clientName;
//   // final List<OnPayloadReceived> _onPayloadReceivedCallbacks = new List<
//   //     OnPayloadReceived>();
//
//   // Manage client state
//   bool isConnected = false;
//   State state = new State();
//
//
//   final BiMap<String, String> _sessionIdClientIdMap = new BiMap<String,
//       String>();
//   final List<String> _clientIds = new List<String>();
//
//   Future<bool> _hasPermissions() async {
//     return await Nearby().checkLocationPermission() &&
//         await Nearby().checkLocationEnabled();
//   }
//
//   Future<bool> _requestPermissions() async {
//     return await Nearby().askLocationPermission() &&
//         await Nearby().enableLocationServices();
//   }
//
//
//   void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
//     LOG.i("Connection initiated: $endpointId, ${ info
//         .authenticationToken }, ${ info.endpointName }, ${ info
//         .isIncomingConnection.toString() }");
//
//     // _sessionIdClientIdMap[id] = info.endpointName;
//     Nearby().acceptConnection(
//       endpointId,
//       onPayLoadRecieved: _onPayLoadReceived,
//     );
//   }
//
//   Future<void> _stateSwitch() {
//     Random rand = new Random();
//     // According to obsecure SO response, avg connection time is 2 ~ 7 seconds.
//     // So we switch every 7 to 15 seconds
//     new Future.delayed(Duration(seconds: rand.nextInt(8) + 7), () async {
//       await stop();
//
//       if (rand.nextInt(1) == 0) {
//         startDiscovery();
//       } else {
//         startAdvertising();
//       }
//
//       // Recursively call
//       _stateSwitch();
//     });
//   }
//
//   Future<void> _onPayLoadReceived(String endpointId, Payload payload) async {
//     if (payload.type == PayloadType.BYTES) {
//       for (OnPayloadReceived callback in _onPayloadReceivedCallbacks) {
//         callback(payload.bytes, endpoints[endpointId]);
//       }
//     }
//   }
//
//   Future<void> _onConnectionResult(String endpointId, Status status) async {
//     switch (status) {
//       case Status.CONNECTED:
//         LOG.i("Connected: ${endpointId}");
//         if (!isConnected) {
//           isConnected = true;
//
//           // TODO: Mikel's random idea using Future.delayed
//           await stop();
//           _stateSwitch();
//         }
//         break;
//       case Status.REJECTED:
//         LOG.w("Connection rejected: ${endpointId}");
//         break;
//       case Status.ERROR:
//         LOG.e("Connection error: ${endpointId}");
//         break;
//       default:
//         LOG.wtf("Connection wtf");
//     }
//   }
//
//
//   Future<void> initialise() async {
//     if (!await _hasPermissions()) {
//       if (!await _requestPermissions()) {
//         throw "Unable to start mesh client.";
//       }
//     }
//   }
//
//   Future<void> start() async {
//     await startDiscovery();
//     await startAdvertising();
//   }
//
//   Future<void> stop() async {
//     await stopDiscovery();
//     await stopAdvertising();
//   }
//
//   Map<String, String> endpoints = new Map();
//
//   Future<void> startDiscovery() async {
//     if (state.discovering) return;
//
//     await Nearby().startDiscovery(
//       _clientName, STRATEGY,
//       onEndpointFound: (endpointId, endpointName, serviceId) async {
//         LOG.i("Endpoint found: ${endpointName}");
//         endpoints[endpointId] = endpointName;
//
//         if (_clientName.compareTo(endpointName) > 0) {
//           // Request a connection
//           await Nearby().requestConnection(
//               _clientName, endpointId,
//               onConnectionInitiated: _onConnectionInitiated,
//               onConnectionResult: _onConnectionResult,
//               onDisconnected: (endpointId) async {
//                 endpoints.remove(endpointId);
//
//                 // Cannot be certain that we're connected
//                 isConnected = false;
//                 await start();
//               }
//           );
//         }
//       },
//       onEndpointLost: (endpointId) {
//         endpoints.remove(endpointId);
//       },
//     );
//
//     state.discovering = true;
//   }
//
//   Future<void> startAdvertising() async {
//     if (state.advertising) return;
//
//     await Nearby().startAdvertising(
//         _clientName, STRATEGY,
//         onConnectionInitiated: (endpointId, ConnectionInfo info) async {
//           Nearby().acceptConnection(
//               endpointId, onPayLoadRecieved: _onPayLoadReceived);
//         },
//         onConnectionResult: (endpointId, Status status) async {
//           switch (status) {
//             case Status.CONNECTED:
//               LOG.i("Connected: ${endpointId}");
//               isConnected = true;
//               await stop();
//               break;
//             case Status.REJECTED:
//               LOG.w("Connection rejected: ${endpointId}");
//               break;
//             case Status.ERROR:
//               LOG.e("Connection error: ${endpointId}");
//               break;
//             default:
//               LOG.wtf("Connection wtf");
//           }
//         },
//         onDisconnected: null
//     );
//
//     state.advertising = true;
//   }
//
//   void stopDiscovery() async {
//     if (!state.discovering) return;
//
//     await Nearby().stopDiscovery();
//     state.discovering = false;
//   }
//
//   void stopAdvertising() async {
//     if (!state.advertising) return;
//
//     await Nearby().stopAdvertising();
//     state.advertising = true;
//   }
//
// }

//
// class MeshClientOld {
//
//
//   final Logger LOG  = Logger();
//   final Strategy STRATEGY = Strategy.P2P_CLUSTER;
//
//   final String _clientName;
//   final List<OnPayLoadReceived> _onPayLoadReceivedCallbacks = new List<OnPayLoadReceived>();
//
//   final BiMap<String, String> _sessionIdClientIdMap = new BiMap<String, String>();
//   final List<String> _clientIds = new List<String>();
//
//   MeshClientOld(this._clientName) {
//     Logger.level = Level.info;
//
//     _enableLocation().then((bool success) async {
//       if (success) await _initService();
//       LOG.i("Service started");
//     });
//   }
//
//   Future<bool> _enableLocation() async {
//     bool locationPermissionGranted = await Nearby().askLocationPermission();
//     bool locationServicesEnabled = await Nearby().enableLocationServices();
//     return locationPermissionGranted && locationServicesEnabled;
//   }
//
//   Future<void> _initService() async {
//     await Nearby().startAdvertising(
//         _clientName, STRATEGY,
//         onConnectionInitiated: _onConnectionInitiated,
//         onConnectionResult: _onConnectionResult,
//         onDisconnected: _onDisconnected
//     );
//
//
//     await Nearby().startDiscovery(
//         _clientName, STRATEGY,
//         onEndpointFound: (id, name, serviceId) async {
//           if (_clientName.compareTo(name) > 0) {
//             LOG.i("Requesting connection to endpoint $name from client $_clientName");
//             try {
//               await Nearby().requestConnection(
//                 _clientName, id,
//                 onConnectionInitiated: _onConnectionInitiated,
//                 onConnectionResult: _onConnectionResult,
//                 onDisconnected: _onDisconnected,
//               );
//             } catch (e) {
//               LOG.e("Connection Request error: ${e.toString()}");
//             }
//           }
//         },
//         onEndpointLost: _onDisconnected
//     );
//   }
//
//   void _onDisconnected(String id) {
//     _clientIds.remove(_sessionIdClientIdMap[id]);
//     _sessionIdClientIdMap.remove(id);
//     LOG.i("Disconnected: $id");
//   }
//
//   void _onConnectionResult(String id, Status status) {
//     if (status == Status.CONNECTED) {
//       LOG.i("Connected: $id");
//       _clientIds.add(_sessionIdClientIdMap[id]);
//     } else {
//       _onDisconnected(id);
//     }
//   }
//
//   void _onConnectionInitiated(String id, ConnectionInfo info) {
//     LOG.i("Connection initiated: $id, ${ info.authenticationToken }, ${ info.endpointName }, ${ info.isIncomingConnection.toString() }");
//
//     _sessionIdClientIdMap[id] = info.endpointName;
//     Nearby().acceptConnection(
//         id,
//         onPayLoadRecieved: (endId, payload) async {
//           if (payload.type == PayloadType.BYTES) {
//             for (OnPayLoadReceived callback in _onPayLoadReceivedCallbacks) {
//               callback(_sessionIdClientIdMap[endId], payload.bytes);
//             }
//           }
//         },
//     );
//   }
//
//   List<String> getClientIds() {
//     return _clientIds;
//   }
//
//
//   void registerOnPayLoadReceivedCallback(OnPayLoadReceived callback) {
//     _onPayLoadReceivedCallbacks.add(callback);
//   }
//
//   // TODO: Add remove function for callbacks
//
//   Future<void> sendPayload(String id, Uint8List payload) async {
//     try {
//       if (_clientIds.contains(id)) await Nearby().sendBytesPayload(_sessionIdClientIdMap.inverse(id), payload);
//       else LOG.e("Send Payload Error. $id not in _clientIds");
//     } catch (e) {
//       LOG.e("Connection request error: ${e.toString()}");
//     }
//   }
//
//   Future<void> broadcastPayload(Uint8List payload) async {
//     for (String id in _clientIds) await sendPayload(id, payload);
//   }
//
// }