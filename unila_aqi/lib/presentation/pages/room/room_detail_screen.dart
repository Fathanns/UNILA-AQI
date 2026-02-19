import 'dart:async';
import 'package:flutter/material.dart';
import 'package:unila_aqi/core/constants/colors.dart';
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinRoomForUpdates();
      _setupRealtimeListener();
      _setupBuildingUpdateListener();
      _setupRoomNameUpdateListener();
      _checkSocketConnection();
    });
  }

  void _setupRoomNameUpdateListener() {
    _socketService.on('room-name-updated', (data) {
      if (_isMounted && data['roomId'] == widget.room.id) {
        final newName = data['newName'];
        final oldName = data['oldName'];

        print('🔄 Room name updated for this room: $oldName -> $newName');

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
    });

    _socketService.on('room-updated', (data) {
      if (_isMounted && data['room']['id'] == widget.room.id) {
        if (data['action'] == 'updated' && data['oldData'] != null) {
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
    _socketService.on('room-building-updated', (data) {
      if (_isMounted && data['buildingId'] == widget.room.buildingId) {
        final newBuildingName = data['newBuildingName'];

        print('🏢 Building name updated for this room: $newBuildingName');

        setState(() {
          _currentRoomData = Room(
            id: _currentRoomData.id,
            name: _currentRoomData.name,
            buildingId: _currentRoomData.buildingId,
            buildingName: newBuildingName,
            dataSource: _currentRoomData.dataSource,
            iotDeviceId: _currentRoomData.iotDeviceId,
            isActive: _currentRoomData.isActive,
            currentAQI: _currentRoomData.currentAQI,
            currentData: _currentRoomData.currentData,
            createdAt: _currentRoomData.createdAt,
            updatedAt: _currentRoomData.updatedAt,
          );
        });

        _showNotification('Nama gedung diperbarui: $newBuildingName', 'info');
      }
    });
  }

  void _joinRoomForUpdates() {
    _socketService.joinRoom(widget.room.id);
  }

  void _setupRealtimeListener() {
    _socketService.on('room-update', (data) {
      if (_isMounted && data['roomId'] == widget.room.id) {
        _handleRoomUpdate(data);
      }
    });

    _socketService.on('notification', (data) {
      if (_isMounted) {
        _showNotification(data['message'], data['type'] ?? 'info');
      }
    });

    _socketConnected = _socketService.isConnected;
  }

  void _handleRoomUpdate(dynamic data) {
    try {
      final roomData = data['data'];
      final oldName = _currentRoomData.name;
      final newName = roomData['name'] ?? _currentRoomData.name;
      final nameChanged = oldName != newName;

      setState(() {
        _currentRoomData = Room(
          id: _currentRoomData.id,
          name: newName,
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
        backgroundColor = Colors.orange.withOpacity(0.9);
        icon = Icons.warning_rounded;
        break;
      case 'error':
        backgroundColor = Colors.red.withOpacity(0.9);
        icon = Icons.error_rounded;
        break;
      case 'success':
        backgroundColor = Colors.green.withOpacity(0.9);
        icon = Icons.check_circle_rounded;
        break;
      default:
        backgroundColor = Colors.blue.withOpacity(0.9);
        icon = Icons.info_rounded;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
    await Future.delayed(Duration(seconds: 1));

    if (_isMounted) {
      setState(() => _isRefreshing = false);
    }
  }

  // ------------------------------------------------------------
  // UI BUILDING METHODS
  // ------------------------------------------------------------

  Widget _buildAQICard() {
    final aqiColor = Helpers.getAQIColor(_currentRoomData.currentAQI);
    final aqiLabel = Helpers.getAQILabel(_currentRoomData.currentAQI);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: aqiColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'INDEKS KUALITAS UDARA',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'AQI',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
              // Sumber data
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _currentRoomData.dataSource == 'iot'
                          ? Icons.sensors_rounded
                          : Icons.auto_awesome_mosaic_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _currentRoomData.dataSource == 'iot' ? 'IoT' : 'Simulasi',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _currentRoomData.currentAQI.toString(),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        aqiLabel.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Progress bar
                    
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParameterCard(String label, String value, String status, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildHealthRecommendations() {
  final aqi = _currentRoomData.currentAQI;
  Helpers.getAQIColor(aqi);
  Helpers.getAQILabel(aqi);
  final recommendations = Helpers.getDetailedRecommendations(_currentRoomData);

  return Container(
    width: double.infinity, // Tambahkan ini agar lebar penuh seperti grafik
    padding: const EdgeInsets.all(12), // Sama dengan padding grafik (12)
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12), // Sama dengan radius grafik (12)
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05), // Sama dengan shadow grafik
          blurRadius: 8,
          offset: const Offset(0, 3), // Sama dengan offset grafik
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Judul dengan gaya seperti grafik historis
        Row(
          children: [
            Icon(
              Icons.health_and_safety_rounded, // Icon health
              color: Colors.blue,
              size: 18,
            ),
            const SizedBox(width: 6),
            const Text(
              'REKOMENDASI KESEHATAN',
              style: TextStyle(
                fontSize: 14, // Sama dengan font grafik
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            // Status chip seperti di grafik
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Helpers.getAQIColor(_currentRoomData.currentAQI),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'AQI: ${_currentRoomData.currentAQI}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12), // Jarak setelah header
        
        // Parameter status chips
        _buildParameterStatus(),
        
        const SizedBox(height: 16),
        
        // Daftar rekomendasi
        ...recommendations.map(_buildRecommendationItem),
      ],
    ),
  );
}

  Widget _buildParameterStatus() {
  final data = _currentRoomData.currentData;

  return Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      _buildStatusChip('PM2.5: ${data.pm25.toStringAsFixed(1)}', Helpers.getPM25Color(data.pm25)),
      _buildStatusChip('PM10: ${data.pm10.toStringAsFixed(1)}', Helpers.getPM10Color(data.pm10)),
      _buildStatusChip('CO₂: ${data.co2.round()}', Helpers.getCO2Color(data.co2)),
      _buildStatusChip('Suhu: ${data.temperature.toStringAsFixed(1)}°C', Helpers.getTemperatureColor(data.temperature)),
      _buildStatusChip('Lembab: ${data.humidity.round()}%', Helpers.getHumidityColor(data.humidity)),
    ],
  );
}

 Widget _buildStatusChip(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );
}

Widget _buildRecommendationItem(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          child: Icon(
            Icons.fiber_manual_record,
            size: 6,
            color: Colors.blueGrey.shade400,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
  text,
  style: TextStyle(
    fontSize: 14,
    color: Colors.black,
    fontWeight: FontWeight.w400,
    height: 1.6,
    letterSpacing: 0.2,
  ),
  textAlign: TextAlign.justify,
),
        ),
      ],
    ),
  );
}

  

  Widget _buildRoomInfoHeader() {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white,
          Colors.grey.shade50,
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.grey.shade200, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 12,
          offset: const Offset(0, 4),
          spreadRadius: -2,
        ),
        BoxShadow(
          color: Colors.blue.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Modern icon dengan gradient
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade400,
                Colors.blue.shade600,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.meeting_room_rounded,
            size: 28,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 16),

        // Informasi ruangan
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nama ruangan
              Text(
                _currentRoomData.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Lokasi gedung
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: Colors.blueGrey.shade400,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _currentRoomData.buildingName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blueGrey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Informasi update terakhir
              Row(
                children: [
                  Icon(
                    Icons.update_rounded,
                    size: 14,
                    color: Colors.blueGrey.shade400,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Diperbarui ${Helpers.formatLastUpdateWithDate(_currentRoomData.currentData.updatedAt)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blueGrey.shade600,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Jika Anda memiliki data status (misal: tersedia/tidak), bisa ditambahkan di sini
        // Contoh: jika ada properti `isAvailable` atau `status`
        // if (_currentRoomData.currentData.isAvailable != null)
        //   Container(
        //     width: 10,
        //     height: 10,
        //     decoration: BoxDecoration(
        //       shape: BoxShape.circle,
        //       color: _currentRoomData.currentData.isAvailable
        //           ? Colors.green.shade400
        //           : Colors.red.shade400,
        //       boxShadow: [
        //         BoxShadow(
        //           color: (_currentRoomData.currentData.isAvailable
        //                   ? Colors.green
        //                   : Colors.red)
        //               .withOpacity(0.4),
        //           blurRadius: 4,
        //         ),
        //       ],
        //     ),
        //   ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
          splashRadius: 20,
        ),
        title: Text(
          'Detail Ruangan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Icon(
                    Icons.refresh_rounded,
                    size: 22,
                    color: AppColors.textSecondary,
                  ),
            onPressed: _refreshData,
            splashRadius: 20,
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Real-time connection status
              if (!_socketConnected)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.wifi_off_rounded,
                          size: 20,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Koneksi terputus',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Mencoba reconnect otomatis...',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.refresh_rounded,
                          size: 20,
                          color: Colors.orange,
                        ),
                        onPressed: _reconnectSocket,
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ),

              // Room info header
              _buildRoomInfoHeader(),

              const SizedBox(height: 16),

              // AQI Card
              _buildAQICard(),

              const SizedBox(height: 16),

              // Last update info
             

            

              // Section Title
              

              // Parameter Grid - First Row
              Row(
                children: [
                  Expanded(
                    child: _buildParameterCard(
                      'PM2.5',
                      _currentRoomData.currentData.pm25.toStringAsFixed(1),
                      Helpers.getPM25Status(_currentRoomData.currentData.pm25),
                      Helpers.getPM25Color(_currentRoomData.currentData.pm25),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildParameterCard(
                      'PM10',
                      _currentRoomData.currentData.pm10.toStringAsFixed(1),
                      Helpers.getPM10Status(_currentRoomData.currentData.pm10),
                      Helpers.getPM10Color(_currentRoomData.currentData.pm10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildParameterCard(
                      'CO₂',
                      '${_currentRoomData.currentData.co2.round()}',
                      Helpers.getCO2Status(_currentRoomData.currentData.co2),
                      Helpers.getCO2Color(_currentRoomData.currentData.co2),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Parameter Grid - Second Row
              Row(
                children: [
                  Expanded(
                    child: _buildParameterCard(
                      'SUHU',
                      '${_currentRoomData.currentData.temperature.toStringAsFixed(1)}°C',
                      Helpers.getTemperatureStatus(_currentRoomData.currentData.temperature),
                      Helpers.getTemperatureColor(_currentRoomData.currentData.temperature),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildParameterCard(
                      'KELEMBABAN',
                      '${_currentRoomData.currentData.humidity.round()}%',
                      Helpers.getHumidityStatus(_currentRoomData.currentData.humidity),
                      Helpers.getHumidityColor(_currentRoomData.currentData.humidity),
                    ),
                  ),
                  const Spacer(),
                ],
              ),

              const SizedBox(height: 24),

              // Health Recommendations
              _buildHealthRecommendations(),

              const SizedBox(height: 24),

              // History Chart Section (tidak diubah)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
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
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'GRAFIK HISTORIS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Update otomatis',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Chart Widget
                    HistoryChart(
                      roomId: _currentRoomData.id,
                      roomName: _currentRoomData.name,
                      buildingName: _currentRoomData.buildingName,
                    ),

               

                    // Info tambahan
                   
                  ],
                ),
              ),
            ],
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