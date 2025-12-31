import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;
  String? _currentRoomId;
  final Map<String, Function(dynamic)> _eventHandlers = {};

  // Getters
  bool get isConnected => _isConnected;
  IO.Socket? get socket => _socket;

  // Connect to server
  Future<void> connect({String? token}) async {
    try {
      if (_socket != null && _isConnected) {
        print('✅ Socket is already connected');
        return;
      }

      print('🔄 Connecting to WebSocket server...');

      // Disconnect existing socket if any
      disconnect();

      // Create new socket connection
      _socket = IO.io(
        'http://10.0.2.2:5000', // Use localhost for emulator
        IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .setExtraHeaders({
            if (token != null) 'Authorization': 'Bearer $token'
          })
          .build(),
      );

      // Setup event listeners
      _setupEventListeners();

      // Connect manually
      _socket!.connect();

    } catch (e) {
      print('❌ Error connecting to WebSocket: $e');
      rethrow;
    }
  }

  // Setup event listeners
  void _setupEventListeners() {
    if (_socket == null) return;

    // Connection established
    _socket!.onConnect((_) {
      _isConnected = true;
      print('✅ WebSocket Connected: ${_socket!.id}');
      
      // Rejoin room if previously joined
      if (_currentRoomId != null) {
        joinRoom(_currentRoomId!);
      }
    });

    // Connection disconnected
    _socket!.onDisconnect((_) {
      _isConnected = false;
      print('❌ WebSocket Disconnected');
    });

    // Connection error
    _socket!.onError((data) {
      print('❌ WebSocket Error: $data');
    });

    // Ping-Pong for connection testing
    _socket!.on('pong', (data) {
      print('🏓 Pong received: $data');
    });

    // Room update handler
    _socket!.on('room-update', (data) {
      print('📡 Room update received: ${data['roomId']}');
      
      // Call registered handlers for this event
      if (_eventHandlers.containsKey('room-update')) {
        _eventHandlers['room-update']!(data);
      }
    });

    // Global notification handler
    _socket!.on('notification', (data) {
      print('🔔 Notification received: ${data['message']}');
      
      if (_eventHandlers.containsKey('notification')) {
        _eventHandlers['notification']!(data);
      }
    });
  }

  // Join a room
  void joinRoom(String roomId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('join-room', roomId);
      _currentRoomId = roomId;
      print('📡 Joined room: $roomId');
    } else {
      print('⚠️ Socket not connected, cannot join room');
    }
  }

  // Leave a room
  void leaveRoom(String roomId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('leave-room', roomId);
      if (_currentRoomId == roomId) {
        _currentRoomId = null;
      }
      print('📡 Left room: $roomId');
    }
  }

  // Send ping to test connection
  void ping() {
    if (_socket != null && _isConnected) {
      _socket!.emit('ping');
      print('🏓 Ping sent');
    }
  }

  // Register event handler
  void on(String event, Function(dynamic) handler) {
    _eventHandlers[event] = handler;
  }

  // Unregister event handler
  void off(String event) {
    _eventHandlers.remove(event);
  }

  // Disconnect from server
  void disconnect() {
    if (_socket != null) {
      // Leave current room
      if (_currentRoomId != null) {
        leaveRoom(_currentRoomId!);
      }
      
      // Disconnect socket
      _socket!.disconnect();
      _socket = null;
      _isConnected = false;
      _currentRoomId = null;
      _eventHandlers.clear();
      print('🔌 WebSocket disconnected');
    }
  }

  // Check connection status
  Future<bool> checkConnection() async {
    if (_socket != null && _isConnected) {
      try {
        // Send ping and wait for pong
        final completer = Completer<bool>();
        
        final tempHandler = (data) {
          completer.complete(true);
        };
        
        _socket!.once('pong', tempHandler);
        ping();
        
        return await completer.future.timeout(
          Duration(seconds: 5),
          onTimeout: () {
            _socket!.off('pong', tempHandler);
            return false;
          },
        );
      } catch (e) {
        return false;
      }
    }
    return false;
  }
}