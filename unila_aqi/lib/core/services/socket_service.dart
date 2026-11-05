import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import 'package:unila_aqi/core/services/storage_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;
  String? _currentRoomId;
  final Map<String, List<Function(dynamic)>> _eventHandlers = {};
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;
  final Duration _reconnectInterval = Duration(seconds: 3);
  bool _isConnecting = false;
  
  // Connection state management
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  final StreamController<Map<String, dynamic>> _dataController = StreamController<Map<String, dynamic>>.broadcast();

  // Getters
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  IO.Socket? get socket => _socket;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;

  // FIXED: helper untuk validasi payload socket.
  // Mengembalikan Map yang aman atau null jika data bukan Map.
  Map<String, dynamic>? _asMap(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      try {
        return Map<String, dynamic>.from(data);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  // Connect to server
  Future<void> connect({String? token}) async {
    if (_isConnecting || _isConnected) {
      if (kDebugMode) {
        print('⚠️ Socket is already connecting or connected');
      }
      return;
    }

    try {
      _isConnecting = true;
      
      if (kDebugMode) {
        print('🔄 Connecting to WebSocket server...');
      }

      // Disconnect existing socket if any
      disconnect();

      // Create new socket connection with optimized settings
      _socket = IO.io(
        'https://unila-aqi.onrender.com', // Use localhost for emulator
        IO.OptionBuilder()
          .setTransports(['websocket', 'polling']) // Prefer WebSocket
          .enableAutoConnect()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .setReconnectionAttempts(_maxReconnectAttempts)
          .setTimeout(30000)
          .setExtraHeaders({
            if (token != null) 'Authorization': 'Bearer $token',
            'Cache-Control': 'no-cache'
          })
          .build(),
      );

      // Setup event listeners
      _setupEventListeners();

      // Connect manually with timeout
      _socket!.connect();
      
      // Set connection timeout
      Timer(Duration(seconds: 10), () {
        if (_isConnecting && !_isConnected) {
          if (kDebugMode) {
            print('❌ Connection timeout');
          }
          _handleConnectionError('Connection timeout');
        }
      });

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error connecting to WebSocket: $e');
      }
      _handleConnectionError(e.toString());
    }
  }

  // Setup event listeners
  void _setupEventListeners() {
    if (_socket == null) return;

    // Connection established
    _socket!.onConnect((_) {
      _isConnecting = false;
      _isConnected = true;
      _reconnectAttempts = 0;
      
      if (_reconnectTimer != null) {
        _reconnectTimer!.cancel();
        _reconnectTimer = null;
      }
      
      if (kDebugMode) {
        print('✅ WebSocket Connected: ${_socket!.id}');
      }
      
      _connectionController.add(true);
      
      // Rejoin room if previously joined
      if (_currentRoomId != null) {
        joinRoom(_currentRoomId!);
      }
      
      // Subscribe to dashboard updates
      _socket!.emit('subscribe-dashboard');
    });

    // Connection disconnected
    _socket!.onDisconnect((_) {
      if (kDebugMode) {
        print('❌ WebSocket Disconnected');
      }
      
      _isConnecting = false;
      _isConnected = false;
      _connectionController.add(false);
      
      // Try to reconnect
      _scheduleReconnect();
    });

    // Connection error
    _socket!.onError((data) {
      if (kDebugMode) {
        print('❌ WebSocket Error: $data');
      }
      _handleConnectionError(data.toString());
    });

    // Connect error
    _socket!.onConnectError((data) {
      if (kDebugMode) {
        print('❌ WebSocket Connect Error: $data');
      }
      _handleConnectionError(data.toString());
    });

    // Ping-Pong for connection testing
    _socket!.on('pong', (data) {
      if (kDebugMode) {
        print('🏓 Pong received: $data');
      }
    });

    // Room update handler - OPTIMIZED
    // FIXED: guard data agar tidak TypeError saat payload rusak.
     _socket!.on('room-update', (data) {
    final map = _asMap(data);
    if (map == null) return;

    if (kDebugMode) {
      print('📡 Room update received: ${map['roomId']}');
    }
    
    // Add timestamp if not present
    if (map['timestamp'] == null) {
      map['timestamp'] = DateTime.now().toIso8601String();
    }
    
    // Call registered handlers for this event
    if (_eventHandlers.containsKey('room-update')) {
      for (final handler in _eventHandlers['room-update']!) {
        try {
          handler(map);
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error in room-update handler: $e');
          }
        }
      }
    }
    
    // Broadcast to data stream
    _dataController.add({
      'type': 'room-update',
      'data': map,
      'timestamp': DateTime.now()
    });
  });

    // Dashboard update handler
    // FIXED: guard data agar tidak TypeError saat payload rusak.
    _socket!.on('dashboard-update', (data) {
      final map = _asMap(data);
      if (map == null) return;

      if (kDebugMode) {
        print('📊 Dashboard update: ${map['type']}');
      }
      
      // Call registered handlers
      if (_eventHandlers.containsKey('dashboard-update')) {
        for (final handler in _eventHandlers['dashboard-update']!) {
          try {
            handler(map);
          } catch (e) {
            if (kDebugMode) {
              print('❌ Error in dashboard-update handler: $e');
            }
          }
        }
      }
      
      // Broadcast to data stream
      _dataController.add({
        'type': 'dashboard-update',
        'data': map,
        'timestamp': DateTime.now()
      });
    });

    // 🔥 BARU: Dashboard room updated handler
  // FIXED: guard data agar tidak TypeError saat payload rusak.
  _socket!.on('dashboard-room-updated', (data) {
    final map = _asMap(data);
    if (map == null) return;

    if (kDebugMode) {
      final room = map['room'];
      final roomName = (room is Map) ? room['name'] : null;
      print('📊 Dashboard room updated: ${map['action']} - $roomName');
    }
    
    // Call registered handlers
    if (_eventHandlers.containsKey('dashboard-room-updated')) {
      for (final handler in _eventHandlers['dashboard-room-updated']!) {
        try {
          handler(map);
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error in dashboard-room-updated handler: $e');
          }
        }
      }
    }
    
    // Broadcast to data stream
    _dataController.add({
      'type': 'dashboard-room-updated',
      'data': map,
      'timestamp': DateTime.now()
    });
  });

  // FIXED: guard data agar tidak TypeError saat payload rusak.
  _socket!.on('room-deleted', (data) {
  final map = _asMap(data);
  if (map == null) return;

  if (kDebugMode) {
    print('🗑️ Room deleted event received: ${map['roomName']} (${map['roomId']})');
  }
  
  // Call registered handlers
  if (_eventHandlers.containsKey('room-deleted')) {
    for (final handler in _eventHandlers['room-deleted']!) {
      try {
        handler(map);
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error in room-deleted handler: $e');
        }
      }
    }
  }
  
  // Broadcast to data stream
  _dataController.add({
    'type': 'room-deleted',
    'data': map,
    'timestamp': DateTime.now()
  });
});

  // 🔥 BARU: Room name changed handler
  // FIXED: guard data agar tidak TypeError saat payload rusak.
  _socket!.on('room-name-changed', (data) {
    final map = _asMap(data);
    if (map == null) return;

    final oldName = map['oldName']?.toString() ?? '-';
    final newName = map['newName']?.toString() ?? '-';

    if (kDebugMode) {
      print('✏️ Room name changed: $oldName -> $newName');
    }
    
    // Call registered handlers
    if (_eventHandlers.containsKey('room-name-changed')) {
      for (final handler in _eventHandlers['room-name-changed']!) {
        try {
          handler(map);
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error in room-name-changed handler: $e');
          }
        }
      }
    }
    
    // Broadcast to data stream
    _dataController.add({
      'type': 'room-name-changed',
      'data': map,
      'timestamp': DateTime.now()
    });
  });

  // 🔥 BARU: Room building changed handler
  // FIXED: guard data agar tidak TypeError saat payload rusak.
  _socket!.on('room-building-changed', (data) {
    final map = _asMap(data);
    if (map == null) return;

    if (kDebugMode) {
      print('🏢 Room building changed: ${map['roomId']}');
    }
    
    // Call registered handlers
    if (_eventHandlers.containsKey('room-building-changed')) {
      for (final handler in _eventHandlers['room-building-changed']!) {
        try {
          handler(map);
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error in room-building-changed handler: $e');
          }
        }
      }
    }
  });

  // Global notification handler
  // FIXED: guard data agar tidak TypeError saat payload rusak.
  _socket!.on('notification', (data) {
    final map = _asMap(data);
    if (map == null) return;

    if (kDebugMode) {
      print('🔔 Notification received: ${map['message']}');
    }
    
    if (_eventHandlers.containsKey('notification')) {
      for (final handler in _eventHandlers['notification']!) {
        try {
          handler(map);
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error in notification handler: $e');
          }
        }
      }
    }
  });
  }

  // Handle connection error
  void _handleConnectionError(String error) {
    _isConnecting = false;
    _isConnected = false;
    _connectionController.add(false);
    
    if (kDebugMode) {
      print('⚠️ Connection error: $error');
    }
    
    _scheduleReconnect();
  }

  // Schedule reconnection
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (kDebugMode) {
        print('⚠️ Max reconnection attempts reached');
      }
      return;
    }

    if (_reconnectTimer == null || !_reconnectTimer!.isActive) {
      _reconnectAttempts++;
      
      if (kDebugMode) {
        print('🔄 Scheduling reconnect attempt $_reconnectAttempts in ${_reconnectInterval.inSeconds}s');
      }

      _reconnectTimer = Timer(_reconnectInterval, () async {
        if (!_isConnected && !_isConnecting) {
          if (kDebugMode) {
            print('🔄 Attempting to reconnect...');
          }
          // Get new token if needed
          final storageService = StorageService();
          final token = await storageService.getString('auth_token');
          await connect(token: token);
        }
      });
    }
  }

  // Join a room
  void joinRoom(String roomId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('join-room', roomId);
      _currentRoomId = roomId;
      
      if (kDebugMode) {
        print('📡 Joined room: $roomId');
      }
    } else {
      if (kDebugMode) {
        print('⚠️ Socket not connected, queuing room join');
      }
      _currentRoomId = roomId;
      
      // Try to connect
      if (!_isConnecting) {
        connect();
      }
    }
  }

  // Leave a room
  void leaveRoom(String roomId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('leave-room', roomId);
      if (_currentRoomId == roomId) {
        _currentRoomId = null;
      }
      
      if (kDebugMode) {
        print('📡 Left room: $roomId');
      }
    }
  }

  // Send ping to test connection
  void ping() {
    if (_socket != null && _isConnected) {
      _socket!.emit('ping');
      
      if (kDebugMode) {
        print('🏓 Ping sent');
      }
    }
  }

  // Request manual refresh
  void requestRefresh() {
    if (_socket != null && _isConnected) {
      _socket!.emit('request-refresh');
      
      if (kDebugMode) {
        print('🔄 Manual refresh requested');
      }
    }
  }

  // Register event handler
  void on(String event, Function(dynamic) handler) {
    if (!_eventHandlers.containsKey(event)) {
      _eventHandlers[event] = [];
    }
    _eventHandlers[event]!.add(handler);
  }

  // Unregister event handler
  void off(String event, [Function(dynamic)? handler]) {
    if (_eventHandlers.containsKey(event)) {
      if (handler != null) {
        _eventHandlers[event]!.remove(handler);
        if (_eventHandlers[event]!.isEmpty) {
          _eventHandlers.remove(event);
        }
      } else {
        _eventHandlers.remove(event);
      }
    }
  }

  // Disconnect from server
  void disconnect() {
    if (_socket != null) {
      // Leave current room
      if (_currentRoomId != null) {
        leaveRoom(_currentRoomId!);
      }
      
      // Cancel reconnect timer
      if (_reconnectTimer != null) {
        _reconnectTimer!.cancel();
        _reconnectTimer = null;
      }
      
      // Disconnect socket
      _socket!.disconnect();
      _socket!.destroy();
      _socket = null;
      
      _isConnecting = false;
      _isConnected = false;
      _currentRoomId = null;
      _eventHandlers.clear();
      _reconnectAttempts = 0;
      
      _connectionController.add(false);
      
      if (kDebugMode) {
        print('🔌 WebSocket disconnected');
      }
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
          Duration(seconds: 3),
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

  // Clean up resources
  void dispose() {
    disconnect();
    _connectionController.close();
    _dataController.close();
  }
}