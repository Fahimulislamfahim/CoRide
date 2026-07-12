import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SocketService {
  IO.Socket? _socket;
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    webOptions: WebOptions(dbName: "CoRideStorage", publicKey: "CoRidePubKey")
  );

  // Cached Room ID for auto-rejoining on drop recovery
  String? _currentRideId;
  
  // Connection State Stream
  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // Real-time Event Streams
  final _locationController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get locationStream => _locationController.stream;

  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;

  // Socket base server URL
  static const String socketUrl = kIsWeb ? 'http://localhost:5000' : 'http://10.0.2.2:5000';
  // Update this to your deployed Render URL in production, e.g. 'https://coride-backend.onrender.com'

  void connect() async {
    if (_socket != null && _socket!.connected) return;

    // Retrieve active session token for WebSocket handshake authentication
    final token = await _storage.read(key: 'jwt_token');

    print('Connecting to Socket server: $socketUrl');
    
    // Configure socket options to handle poor network along Birulia embankment
    _socket = IO.io(socketUrl, IO.OptionBuilder()
      .setTransports(['websocket']) // Force WebSocket only for performance
      .setAuth({'token': token ?? ''}) // Handshake Authentication Payload
      .enableAutoConnect()
      .enableReconnection()
      .setReconnectionDelay(2000)
      .setReconnectionAttempts(20) // Retries for up to 40 seconds of dropouts
      .build()
    );

    _socket!.onConnect((_) {
      print('[Socket] Connected to server successfully');
      _isConnected = true;
      _connectionController.add(true);

      // Auto-rejoin previous room if connection dropped and recovered (embankment fallback)
      if (_currentRideId != null) {
        _socket!.emit('join_ride_room', _currentRideId);
        print('[Socket Recovery] Automatically rejoined ride room: $_currentRideId');
      }
    });

    _socket!.onDisconnect((_) {
      print('[Socket] Disconnected from server');
      _isConnected = false;
      _connectionController.add(false);
    });

    _socket!.onConnectError((data) {
      print('[Socket] Connection Error: $data');
      _isConnected = false;
      _connectionController.add(false);
    });

    // Real-time coordinates update listener
    _socket!.on('location_update', (data) {
      if (data is Map) {
        _locationController.add(Map<String, dynamic>.from(data));
      }
    });

    // Ride status changed sync listener
    _socket!.on('status_update', (data) {
      if (data is Map) {
        _statusController.add(Map<String, dynamic>.from(data));
      }
    });
  }

  // API Methods
  void joinRideRoom(String rideId) {
    _currentRideId = rideId; // Cache room ID
    if (_socket == null || !_isConnected) {
      print('[Socket Warning] Cannot join room, socket not connected.');
      return;
    }
    _socket!.emit('join_ride_room', rideId);
    print('[Socket] Emitted join_ride_room for Ride ID: $rideId');
  }

  void leaveRideRoom() {
    _currentRideId = null;
    print('[Socket] Cleared cached room ID');
  }

  void updateLocation(String rideId, double lat, double lng, {double speed = 0.0}) {
    if (_socket == null || !_isConnected) {
      print('[Socket Warning] Cannot send location update, socket not connected.');
      return;
    }
    _socket!.emit('update_location', {
      'rideId': rideId,
      'lat': lat,
      'lng': lng,
      'speed': speed,
    });
  }

  void updateRideStatus(String rideId, String status) {
    if (_socket == null || !_isConnected) {
      print('[Socket Warning] Cannot send status update, socket not connected.');
      return;
    }
    _socket!.emit('ride_status_changed', {
      'rideId': rideId,
      'status': status,
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.close();
    _socket = null;
    _isConnected = false;
    _connectionController.add(false);
    print('[Socket] Closed and resources released');
  }

  void dispose() {
    disconnect();
    _connectionController.close();
    _locationController.close();
    _statusController.close();
  }
}
