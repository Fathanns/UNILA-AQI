import 'package:flutter/material.dart';
import 'package:unila_aqi/core/constants/colors.dart';
import 'package:unila_aqi/core/services/socket_service.dart';
import 'package:unila_aqi/core/utils/helpers.dart';
import 'package:unila_aqi/data/models/room.dart';
import 'package:unila_aqi/data/repositories/room_repository.dart';
import 'package:unila_aqi/presentation/widgets/chart/history_chart.dart';
import '../../widgets/common/server_status_indicator.dart';

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
  final RoomRepository _roomRepository = RoomRepository();

  bool _isRefreshing = false;
  bool _isMounted = false;
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
      _ensureSocketConnected();
    });
  }

  void _ensureSocketConnected() {
    if (!_socketService.isConnected && _isMounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _reconnectSocket();
      });
    }
  }

  Future<void> _reconnectSocket() async {
    try {
      await _socketService.connect();
      await Future.delayed(const Duration(seconds: 2));
      if (_socketService.isConnected) {
        _joinRoomForUpdates();
      }
    } catch (e) {
      print('❌ Failed to reconnect: $e');
    }
  }

  void _setupRoomNameUpdateListener() {
    _socketService.on('room-name-updated', (data) {
      if (_isMounted && data['roomId'] == widget.room.id) {
        final newName = data['newName'];
        final oldName = data['oldName'];

        setState(() {
          _currentRoomData = Room(
            id: _currentRoomData.id,
            name: newName,
            buildingId: _currentRoomData.buildingId,
            buildingName: _currentRoomData.buildingName,
            dataSource: _currentRoomData.dataSource,
            iotDeviceId: _currentRoomData.iotDeviceId,
            currentAQI: _currentRoomData.currentAQI,
            currentData: _currentRoomData.currentData,
            createdAt: _currentRoomData.createdAt,
            updatedAt: DateTime.now(),
          );
        });

        _showNotification(
            'Nama ruangan diperbarui: $oldName -> $newName', 'info');
      }
    });

    _socketService.on('room-updated', (data) {
      if (_isMounted && data['room']['id'] == widget.room.id) {
        if (data['action'] == 'updated' && data['oldData'] != null) {
          final newName = data['room']['name'];
          final oldName = data['oldData']['name'];

          if (newName != oldName) {
            setState(() {
              _currentRoomData = Room(
                id: _currentRoomData.id,
                name: newName,
                buildingId: _currentRoomData.buildingId,
                buildingName: _currentRoomData.buildingName,
                dataSource: _currentRoomData.dataSource,
                iotDeviceId: _currentRoomData.iotDeviceId,
                currentAQI: _currentRoomData.currentAQI,
                currentData: _currentRoomData.currentData,
                createdAt: _currentRoomData.createdAt,
                updatedAt: DateTime.now(),
              );
            });

            _showNotification(
                'Nama ruangan diperbarui: $oldName -> $newName',
                'info');
          }
        }
      }
    });
  }

  void _setupBuildingUpdateListener() {
    _socketService.on('room-building-updated', (data) {
      if (_isMounted && data['buildingId'] == widget.room.buildingId) {
        final newBuildingName = data['newBuildingName'];

        setState(() {
          _currentRoomData = Room(
            id: _currentRoomData.id,
            name: _currentRoomData.name,
            buildingId: _currentRoomData.buildingId,
            buildingName: newBuildingName,
            dataSource: _currentRoomData.dataSource,
            iotDeviceId: _currentRoomData.iotDeviceId,
            currentAQI: _currentRoomData.currentAQI,
            currentData: _currentRoomData.currentData,
            createdAt: _currentRoomData.createdAt,
            updatedAt: _currentRoomData.updatedAt,
          );
        });

        _showNotification('Nama gedung diperbarui: $newBuildingName',
            'info');
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
          currentAQI: roomData['currentAQI'],
          currentData: RoomData(
            pm25: roomData['currentData']['pm25'].toDouble(),
            pm10: roomData['currentData']['pm10'].toDouble(),
            co2: roomData['currentData']['co2'].toDouble(),
            temperature:
                roomData['currentData']['temperature'].toDouble(),
            humidity: roomData['currentData']['humidity'].toDouble(),
            updatedAt: DateTime.parse(
                roomData['currentData']['updatedAt']),
          ),
          createdAt: _currentRoomData.createdAt,
          updatedAt: DateTime.parse(roomData['updatedAt']),
        );
      });

      if (nameChanged) {
        _showNotification(
            'Nama ruangan diperbarui: $oldName -> $newName', 'info');
      }
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
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Fetch data terbaru dari server.
  Future<void> _refreshData() async {
    if (!_isMounted) return;

    setState(() => _isRefreshing = true);

    try {
      final freshRoom =
          await _roomRepository.getRoomById(widget.room.id);
      if (_isMounted) {
        setState(() {
          _currentRoomData = freshRoom;
        });
      }
    } catch (e) {
      if (_isMounted) {
        if (Helpers.isNetworkError(e)) {
          Helpers.showServerError(context);
        } else {
          Helpers.showSnackBar(
            context,
            'Gagal refresh data ruangan',
            isError: true,
          );
        }
      }
    } finally {
      if (_isMounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  // ------------------------------------------------------------
  // UI BUILDING METHODS (tidak berubah dari versi sebelumnya)
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
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
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
                      _currentRoomData.dataSource == 'iot'
                          ? 'IoT'
                          : 'Simulasi',
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
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
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParameterCard(
      String label, String value, String status, Color color) {
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
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    final recommendations =
        Helpers.getDetailedRecommendations(_currentRoomData);

    return Container(
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
                Icons.health_and_safety_rounded,
                color: Colors.blue,
                size: 18,
              ),
              const SizedBox(width: 6),
              const Text(
                'REKOMENDASI KESEHATAN',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
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
                        color: Helpers.getAQIColor(
                            _currentRoomData.currentAQI),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'AQI: $aqi',
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
          const SizedBox(height: 12),
          _buildParameterStatus(),
          const SizedBox(height: 16),
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
        _buildStatusChip('PM2.5: ${data.pm25.toStringAsFixed(1)}',
            Helpers.getPM25Color(data.pm25)),
        _buildStatusChip('PM10: ${data.pm10.toStringAsFixed(1)}',
            Helpers.getPM10Color(data.pm10)),
        _buildStatusChip(
            'CO₂: ${data.co2.round()}', Helpers.getCO2Color(data.co2)),
        _buildStatusChip(
            'Suhu: ${data.temperature.toStringAsFixed(1)}°C',
            Helpers.getTemperatureColor(data.temperature)),
        _buildStatusChip(
            'Lembab: ${data.humidity.round()}%',
            Helpers.getHumidityColor(data.humidity)),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_right, size: 16, color: Colors.grey),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Colors.black,
                height: 1.4,
              ),
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
          colors: [Colors.white, Colors.grey.shade50],
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
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade400, Colors.blue.shade600],
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentRoomData.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
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
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
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
        title: const Text(
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
          const ServerStatusIndicator(),
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
                : const Icon(
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
              _buildRoomInfoHeader(),
              const SizedBox(height: 16),
              _buildAQICard(),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildParameterCard(
                      'PM2.5',
                      _currentRoomData.currentData.pm25
                          .toStringAsFixed(1),
                      Helpers.getPM25Status(
                          _currentRoomData.currentData.pm25),
                      Helpers.getPM25Color(
                          _currentRoomData.currentData.pm25),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildParameterCard(
                      'PM10',
                      _currentRoomData.currentData.pm10
                          .toStringAsFixed(1),
                      Helpers.getPM10Status(
                          _currentRoomData.currentData.pm10),
                      Helpers.getPM10Color(
                          _currentRoomData.currentData.pm10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildParameterCard(
                      'CO₂',
                      '${_currentRoomData.currentData.co2.round()}',
                      Helpers.getCO2Status(
                          _currentRoomData.currentData.co2),
                      Helpers.getCO2Color(
                          _currentRoomData.currentData.co2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildParameterCard(
                      'SUHU',
                      '${_currentRoomData.currentData.temperature.toStringAsFixed(1)}°C',
                      Helpers.getTemperatureStatus(
                          _currentRoomData.currentData.temperature),
                      Helpers.getTemperatureColor(
                          _currentRoomData.currentData.temperature),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildParameterCard(
                      'KELEMBABAN',
                      '${_currentRoomData.currentData.humidity.round()}%',
                      Helpers.getHumidityStatus(
                          _currentRoomData.currentData.humidity),
                      Helpers.getHumidityColor(
                          _currentRoomData.currentData.humidity),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 24),

              _buildHealthRecommendations(),
              const SizedBox(height: 24),

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
                    const Row(
                      children: [
                        Icon(Icons.timeline,
                            color: Colors.blue, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'GRAFIK HISTORIS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Spacer(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    HistoryChart(
                      roomId: _currentRoomData.id,
                      roomName: _currentRoomData.name,
                      buildingName: _currentRoomData.buildingName,
                    ),
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

    _socketService.leaveRoom(widget.room.id);

    _socketService.off('room-update');
    _socketService.off('notification');
    _socketService.off('room-building-updated');
    _socketService.off('room-name-updated');
    _socketService.off('room-updated');

    super.dispose();
  }
}