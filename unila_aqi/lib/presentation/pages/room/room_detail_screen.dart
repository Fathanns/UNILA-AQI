import 'dart:async';
import 'package:flutter/material.dart';
import 'package:unila_aqi/core/constants/colors.dart';
// import 'package:unila_aqi/core/services/api_service.dart';
import 'package:unila_aqi/core/services/socket_service.dart';
import 'package:unila_aqi/core/utils/helpers.dart';
import 'package:unila_aqi/data/models/room.dart';
import 'package:unila_aqi/presentation/widgets/chart/history_chart.dart';

class RoomDetailScreen extends StatefulWidget {
  final Room room;

  const RoomDetailScreen({
    super.key,
    required this.room,
  });

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  // final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();

  bool _isRefreshing = false;
  bool _isMounted = false;
  bool _socketConnected = false;
  late Room _currentRoomData;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _currentRoomData = widget.room;

    // Join room for real-time updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinRoomForUpdates();
      _setupRealtimeListener();
      _setupBuildingUpdateListener();
      _setupRoomNameUpdateListener();
      _checkSocketConnection();
    });
  }

  void _setupRoomNameUpdateListener() {
    // Listen for room name updates
    _socketService.on('room-name-updated', (data) {
      if (_isMounted && data['roomId'] == widget.room.id) {
        final newName = data['newName'];
        final oldName = data['oldName'];

        print('🔄 Room name updated for this room: $oldName -> $newName');

        // Update room data dengan nama baru
        setState(() {
          _currentRoomData = Room(
            id: _currentRoomData.id,
            name: newName, // Update nama ruangan
            buildingId: _currentRoomData.buildingId,
            buildingName: _currentRoomData.buildingName,
            dataSource: _currentRoomData.dataSource,
            iotDeviceId: _currentRoomData.iotDeviceId,
            isActive: _currentRoomData.isActive,
            currentAQI: _currentRoomData.currentAQI,
            currentData: _currentRoomData.currentData,
            createdAt: _currentRoomData.createdAt,
            updatedAt: DateTime.now(),
          );
        });

        // Show notification
        _showNotification('Nama ruangan diperbarui: $oldName -> $newName', 'info');
      }
    });

    // Listen for room-updated events (general updates)
    _socketService.on('room-updated', (data) {
      if (_isMounted && data['room']['id'] == widget.room.id) {
        if (data['action'] == 'updated' && data['oldData']) {
          final newName = data['room']['name'];
          final oldName = data['oldData']['name'];

          if (newName != oldName) {
            print('🔄 Detected room name change in room-updated event');

            setState(() {
              _currentRoomData = Room(
                id: _currentRoomData.id,
                name: newName,
                buildingId: _currentRoomData.buildingId,
                buildingName: _currentRoomData.buildingName,
                dataSource: _currentRoomData.dataSource,
                iotDeviceId: _currentRoomData.iotDeviceId,
                isActive: _currentRoomData.isActive,
                currentAQI: _currentRoomData.currentAQI,
                currentData: _currentRoomData.currentData,
                createdAt: _currentRoomData.createdAt,
                updatedAt: DateTime.now(),
              );
            });

            _showNotification('Nama ruangan diperbarui: $oldName -> $newName', 'info');
          }
        }
      }
    });
  }

  void _setupBuildingUpdateListener() {
    // Listen for building name updates specific to this room
    _socketService.on('room-building-updated', (data) {
      if (_isMounted && data['buildingId'] == widget.room.buildingId) {
        final newBuildingName = data['newBuildingName'];

        print('🏢 Building name updated for this room: $newBuildingName');

        // Update room data with new building name
        setState(() {
          _currentRoomData = Room(
            id: _currentRoomData.id,
            name: _currentRoomData.name,
            buildingId: _currentRoomData.buildingId,
            buildingName: newBuildingName, // Update building name
            dataSource: _currentRoomData.dataSource,
            iotDeviceId: _currentRoomData.iotDeviceId,
            isActive: _currentRoomData.isActive,
            currentAQI: _currentRoomData.currentAQI,
            currentData: _currentRoomData.currentData,
            createdAt: _currentRoomData.createdAt,
            updatedAt: _currentRoomData.updatedAt,
          );
        });

        // Show notification
        _showNotification('Nama gedung diperbarui: $newBuildingName', 'info');
      }
    });
  }

  void _joinRoomForUpdates() {
    _socketService.joinRoom(widget.room.id);
  }

  void _setupRealtimeListener() {
    // Listen for room updates from SocketService
    _socketService.on('room-update', (data) {
      if (_isMounted && data['roomId'] == widget.room.id) {
        _handleRoomUpdate(data);
      }
    });

    // Listen for notifications
    _socketService.on('notification', (data) {
      if (_isMounted) {
        _showNotification(data['message'], data['type'] ?? 'info');
      }
    });

    // Update connection status
    _socketConnected = _socketService.isConnected;
  }

  void _handleRoomUpdate(dynamic data) {
    try {
      final roomData = data['data'];

      // 🔥 BARU: Check if name has changed
      final oldName = _currentRoomData.name;
      final newName = roomData['name'] ?? _currentRoomData.name;
      final nameChanged = oldName != newName;

      setState(() {
        _currentRoomData = Room(
          id: _currentRoomData.id,
          name: newName, // 🔥 BARU: Gunakan nama baru jika ada
          buildingId: _currentRoomData.buildingId,
          buildingName: _currentRoomData.buildingName,
          dataSource: _currentRoomData.dataSource,
          iotDeviceId: _currentRoomData.iotDeviceId,
          isActive: _currentRoomData.isActive,
          currentAQI: roomData['currentAQI'],
          currentData: RoomData(
            pm25: roomData['currentData']['pm25'].toDouble(),
            pm10: roomData['currentData']['pm10'].toDouble(),
            co2: roomData['currentData']['co2'].toDouble(),
            temperature: roomData['currentData']['temperature'].toDouble(),
            humidity: roomData['currentData']['humidity'].toDouble(),
            updatedAt: DateTime.parse(roomData['currentData']['updatedAt']),
          ),
          createdAt: _currentRoomData.createdAt,
          updatedAt: DateTime.parse(roomData['updatedAt']),
        );
      });

      // Show update notification
      if (nameChanged) {
        _showNotification('Nama ruangan diperbarui: $oldName -> $newName', 'info');
      }

      print('🔄 Real-time update: Room ${_currentRoomData.name} - AQI ${_currentRoomData.currentAQI}');
    } catch (e) {
      print('❌ Error handling room update: $e');
    }
  }

  void _showNotification(String message, String type) {
    Color backgroundColor;
    IconData icon;

    switch (type) {
      case 'warning':
        backgroundColor = Colors.orange;
        icon = Icons.warning;
        break;
      case 'error':
        backgroundColor = Colors.red;
        icon = Icons.error;
        break;
      case 'success':
        backgroundColor = Colors.green;
        icon = Icons.check_circle;
        break;
      default:
        backgroundColor = Colors.blue;
        icon = Icons.info;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _checkSocketConnection() {
    setState(() {
      _socketConnected = _socketService.isConnected;
    });

    if (!_socketConnected && _isMounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNotification('Koneksi real-time terputus. Mencoba reconnect...', 'warning');
        _reconnectSocket();
      });
    }
  }

  Future<void> _reconnectSocket() async {
    try {
      await _socketService.connect();
      await Future.delayed(Duration(seconds: 2));
      if (_socketService.isConnected) {
        _joinRoomForUpdates();
        setState(() {
          _socketConnected = true;
        });
        _showNotification('Koneksi real-time berhasil dipulihkan', 'success');
      }
    } catch (e) {
      print('❌ Failed to reconnect: $e');
    }
  }

  Future<void> _refreshData() async {
    if (!_isMounted) return;

    setState(() => _isRefreshing = true);
    
    // In a real app, you would refresh the current data
    await Future.delayed(Duration(seconds: 1)); // Simulate network delay

    if (_isMounted) {
      setState(() => _isRefreshing = false);
    }
  }

  Widget _buildParameterCard(String label, String value, String status, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthRecommendations() {
    final aqi = _currentRoomData.currentAQI;
    final aqiColor = Helpers.getAQIColor(aqi);
    final recommendations = Helpers.getDetailedRecommendations(_currentRoomData);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.health_and_safety,
                color: aqiColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'REKOMENDASI KESEHATAN:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: aqiColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Parameter Status
          _buildParameterStatus(),
          const SizedBox(height: 12),

          // Recommendations List
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: recommendations.map((rec) => _buildRecommendationItem(rec)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterStatus() {
    final data = _currentRoomData.currentData;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildStatusChip('PM2.5: ${data.pm25.toStringAsFixed(1)}', 
            Helpers.getPM25Color(data.pm25)),
        _buildStatusChip('PM10: ${data.pm10.toStringAsFixed(1)}', 
            Helpers.getPM25Color(data.pm10)),
        _buildStatusChip('CO₂: ${data.co2.round()}', 
            Helpers.getCO2Color(data.co2)),
        _buildStatusChip('Suhu: ${data.temperature.toStringAsFixed(1)}°C', 
            Helpers.getTemperatureColor(data.temperature)),
        _buildStatusChip('Lembab: ${data.humidity.round()}%', 
            Helpers.getHumidityColor(data.humidity)),
      ],
    );
  }

  Widget _buildStatusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildRecommendationItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.arrow_right,
            size: 16,
            color: Colors.grey,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdateInfo() {
    final lastUpdateFormatted = Helpers.formatLastUpdateWithDate(_currentRoomData.currentData.updatedAt);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.update,
            size: 16,
            color: Colors.grey,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update terakhir',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  lastUpdateFormatted,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _currentRoomData.isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentRoomData.isActive ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  _currentRoomData.isActive ? 'Aktif' : 'Nonaktif',
                  style: TextStyle(
                    fontSize: 10,
                    color: _currentRoomData.isActive ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final aqiColor = Helpers.getAQIColor(_currentRoomData.currentAQI);
    final aqiLabel = Helpers.getAQILabel(_currentRoomData.currentAQI);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('UNILA Air Quality Index'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh manual',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Real-time connection status
                if (!_socketConnected)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.wifi_off, size: 20, color: Colors.orange),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Koneksi real-time terputus',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Data mungkin tidak update secara real-time. Mencoba reconnect otomatis...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.refresh, size: 18),
                          onPressed: _reconnectSocket,
                          color: Colors.orange,
                        ),
                      ],
                    ),
                  ),

                // Room header with AQI
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      // AQI Circle
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: aqiColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: aqiColor,
                            width: 3,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentRoomData.currentAQI.toString(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: aqiColor,
                              ),
                            ),
                            Text(
                              'AQI',
                              style: TextStyle(
                                fontSize: 12,
                                color: aqiColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(width: 16),

                      // Room info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentRoomData.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _currentRoomData.buildingName,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: aqiColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                aqiLabel,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Data source indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _currentRoomData.dataSource == 'iot' 
                              ? Colors.blue.withOpacity(0.1) 
                              : Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _currentRoomData.dataSource == 'iot' 
                                  ? Icons.sensors 
                                  : Icons.auto_awesome,
                              size: 12,
                              color: _currentRoomData.dataSource == 'iot' 
                                  ? Colors.blue 
                                  : Colors.purple,
                            ),
                            SizedBox(width: 4),
                            Text(
                              _currentRoomData.dataSource == 'iot' ? 'IoT' : 'Simulasi',
                              style: TextStyle(
                                fontSize: 10,
                                color: _currentRoomData.dataSource == 'iot' 
                                    ? Colors.blue 
                                    : Colors.purple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // Last update info
                _buildLastUpdateInfo(),

                SizedBox(height: 24),

                // Parameter Cards
                const Text(
                  'PARAMETER KUALITAS UDARA:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                // First Row: PM2.5, PM10, CO2
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                  children: [
                    _buildParameterCard(
                      'PM2.5',
                      _currentRoomData.currentData.pm25.toStringAsFixed(1),
                      Helpers.getPM25Status(_currentRoomData.currentData.pm25),
                      Helpers.getPM25Color(_currentRoomData.currentData.pm25),
                    ),
                    _buildParameterCard(
                      'PM10',
                      _currentRoomData.currentData.pm10.toStringAsFixed(1),
                      Helpers.getPM25Status(_currentRoomData.currentData.pm10),
                      Helpers.getPM25Color(_currentRoomData.currentData.pm10),
                    ),
                    _buildParameterCard(
                      'CO₂',
                      '${_currentRoomData.currentData.co2.round()}',
                      Helpers.getCO2Status(_currentRoomData.currentData.co2),
                      Helpers.getCO2Color(_currentRoomData.currentData.co2),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // Second Row: Temperature, Humidity
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: [
                    _buildParameterCard(
                      'SUHU',
                      '${_currentRoomData.currentData.temperature.toStringAsFixed(1)}°C',
                      Helpers.getTemperatureStatus(_currentRoomData.currentData.temperature),
                      Helpers.getTemperatureColor(_currentRoomData.currentData.temperature),
                    ),
                    _buildParameterCard(
                      'KELEMBABAN',
                      '${_currentRoomData.currentData.humidity.round()}%',
                      Helpers.getHumidityStatus(_currentRoomData.currentData.humidity),
                      Helpers.getHumidityColor(_currentRoomData.currentData.humidity),
                    ),
                  ],
                ),

                SizedBox(height: 24),

                // Health Recommendations
                _buildHealthRecommendations(),

                SizedBox(height: 24),

                // History Chart Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.timeline,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'GRAFIK HISTORIS 24 JAM',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          
                        ],
                      ),
                      const SizedBox(height: 4),
                    //  Container(
                    //         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    //         decoration: BoxDecoration(
                    //           color: Colors.blue.withOpacity(0.1),
                    //           borderRadius: BorderRadius.circular(8),
                    //         ),
                    //         child: Row(
                    //           children: [
                    //             Container(
                    //               width: 8,
                    //               height: 8,
                    //               decoration: const BoxDecoration(
                    //                 color: Colors.blue,
                    //                 shape: BoxShape.circle,
                    //               ),
                    //             ),
                    //             const SizedBox(width: 4),
                    //             Text(
                    //               'Update setiap 30 menit',
                    //               style: TextStyle(
                    //                 fontSize: 10,
                    //                 color: Colors.blue.shade700,
                    //                 fontWeight: FontWeight.w500,
                    //               ),
                    //             ),
                    //           ],
                    //         ),
                    //       ),
                      
                      
                      // Chart Widget
                      HistoryChart(
                        roomId: _currentRoomData.id,
                        roomName: _currentRoomData.name,
                        buildingName: _currentRoomData.buildingName,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Chart Legend
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _buildLegendItem('AQI', Colors.blue),
                          _buildLegendItem('PM2.5', Colors.red),
                          _buildLegendItem('PM10', Colors.orange),
                          _buildLegendItem('CO₂', Colors.green),
                          _buildLegendItem('Suhu', Colors.purple),
                          _buildLegendItem('Kelembaban', Colors.teal),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _isMounted = false;

    // Leave room
    _socketService.leaveRoom(widget.room.id);

    // Remove event listeners
    _socketService.off('room-update');
    _socketService.off('notification');
    _socketService.off('room-building-updated');
    _socketService.off('room-name-updated');
    _socketService.off('room-updated');

    super.dispose();
  }
}