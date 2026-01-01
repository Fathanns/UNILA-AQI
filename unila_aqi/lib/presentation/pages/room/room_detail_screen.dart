import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:unila_aqi/core/utils/date_formatter.dart';
import 'package:unila_aqi/data/models/sensor_data.dart';
import '../../../data/models/room.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/constants/colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/socket_service.dart';

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
  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();
  
  List<SensorDataPoint> _historicalData = [];
  bool _isLoadingHistory = false;
  String _selectedChartRange = '24h';
  Timer? _autoRefreshTimer;
  int _autoRefreshCountdown = 5;
  bool _isRefreshing = false;
  bool _isMounted = false;
  bool _socketConnected = false;
  late Room _currentRoomData;
  StreamSubscription? _roomUpdateSubscription;
  
  // Chart control
  int _selectedChartType = 0; // 0: AQI, 1: PM2.5, 2: Temperature
  bool _showChartGrid = true;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _currentRoomData = widget.room;
    
    // Join room for real-time updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinRoomForUpdates();
      _setupRealtimeListener();
      _loadHistoricalData();
      _startAutoRefresh();
      _checkSocketConnection();
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
      DateTime.parse(data['timestamp']);
      
      setState(() {
        _currentRoomData = Room(
          id: _currentRoomData.id,
          name: _currentRoomData.name,
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

      // Add to historical data for chart
      _addToHistoricalData(_currentRoomData);

      // Show update notification
      // _showUpdateNotification(_currentRoomData);

      print('🔄 Real-time update: Room ${_currentRoomData.name} - AQI ${_currentRoomData.currentAQI}');
    } catch (e) {
      print('❌ Error handling room update: $e');
    }
  }

  void _addToHistoricalData(Room room) {
    // Limit historical data to 50 points
    if (_historicalData.length >= 50) {
      _historicalData.removeAt(0);
    }
    
    _historicalData.add(SensorDataPoint(
      timestamp: room.updatedAt,
      aqi: room.currentAQI,
      pm25: room.currentData.pm25,
      pm10: room.currentData.pm10,
      co2: room.currentData.co2,
      temperature: room.currentData.temperature,
      humidity: room.currentData.humidity,
    ));
  }

  // void _showUpdateNotification(Room updatedRoom) {
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Row(
  //         children: [
  //           Icon(Icons.update, color: Colors.white, size: 20),
  //           SizedBox(width: 8),
  //           Expanded(
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Text(
  //                   'Data diperbarui',
  //                   style: TextStyle(fontWeight: FontWeight.bold),
  //                 ),
  //                 SizedBox(height: 2),
  //                 Text(
  //                   'AQI: ${updatedRoom.currentAQI} (${Helpers.getAQILabel(updatedRoom.currentAQI)})',
  //                   style: TextStyle(fontSize: 12),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ],
  //       ),
  //       backgroundColor: Helpers.getAQIColor(updatedRoom.currentAQI),
  //       duration: Duration(seconds: 3),
  //       behavior: SnackBarBehavior.floating,
  //       shape: RoundedRectangleBorder(
  //         borderRadius: BorderRadius.circular(8),
  //       ),
  //     ),
  //   );
  // }

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

Future<void> _loadHistoricalData() async {
  if (!_isMounted) return;
  
  setState(() => _isLoadingHistory = true);
  
  try {
    final response = await _apiService.getSensorData(
      widget.room.id,
      range: _selectedChartRange,
    );
    
    if (_isMounted && response['success'] == true) {
      final List<dynamic> data = response['data'];
      _historicalData = data.map((json) => SensorDataPoint(
        timestamp: DateTime.parse(json['timestamp']),
        aqi: json['aqi']?.toInt() ?? 0,
        pm25: (json['pm25'] ?? 0).toDouble(),
        pm10: (json['pm10'] ?? 0).toDouble(),
        co2: (json['co2'] ?? 450).toDouble(),
        temperature: (json['temperature'] ?? 25).toDouble(),
        humidity: (json['humidity'] ?? 50).toDouble(),
      )).toList();
    }
  } catch (e) {
    print('Error loading historical data: $e');
    _showNotification('Gagal memuat data historis', 'error');
  } finally {
    if (_isMounted) {
      setState(() => _isLoadingHistory = false);
    }
  }
}

  @override
  void dispose() {
    _isMounted = false;
    
    // Leave room
    _socketService.leaveRoom(widget.room.id);
    
    // Remove event listeners
    _socketService.off('room-update');
    _socketService.off('notification');
    
    // Cancel subscription
    _roomUpdateSubscription?.cancel();
    
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isMounted) {
        timer.cancel();
        return;
      }
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isMounted) return;
        
        setState(() {
          if (_autoRefreshCountdown <= 0) {
            _autoRefreshCountdown = 5;
            _refreshData();
          } else {
            _autoRefreshCountdown--;
          }
        });
      });
    });
  }

  Future<void> _refreshData() async {
    if (!_isMounted) return;
    
    setState(() => _isRefreshing = true);
    await _loadHistoricalData();
    
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

  Widget _buildAQIChart() {
    if (_isLoadingHistory) {
      return SizedBox(
        height: 250,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_historicalData.isEmpty) {
      return Container(
        height: 250,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timeline, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Tidak ada data historis tersedia',
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text(
                'Data akan muncul saat sensor mengirim pembacaan',
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    // Prepare chart data based on selected type
    List<FlSpot> spots = [];
    double minY = 0;
    double maxY = 100;
    String unit = '';

    switch (_selectedChartType) {
      case 0: // AQI
        spots = _historicalData.asMap().entries.map((entry) {
          final index = entry.key.toDouble();
          final data = entry.value;
          return FlSpot(index, data.aqi.toDouble());
        }).toList();
        minY = 0;
        maxY = 500;
        unit = 'AQI';
        break;
        
      case 1: // PM2.5
        spots = _historicalData.asMap().entries.map((entry) {
          final index = entry.key.toDouble();
          final data = entry.value;
          return FlSpot(index, data.pm25);
        }).toList();
        minY = 0;
        maxY = 250;
        unit = 'μg/m³';
        break;
        
      case 2: // Temperature
        spots = _historicalData.asMap().entries.map((entry) {
          final index = entry.key.toDouble();
          final data = entry.value;
          return FlSpot(index, data.temperature);
        }).toList();
        minY = 15;
        maxY = 35;
        unit = '°C';
        break;
    }

    // Calculate min/max with padding
    final values = spots.map((spot) => spot.y).toList();
double chartMinY;
double chartMaxY;

if (values.isNotEmpty) {
  // Konversi ke double dan gunakan .toDouble()
  final minValue = values.reduce((a, b) => a < b ? a : b).toDouble();
  final maxValue = values.reduce((a, b) => a > b ? a : b).toDouble();
  
  chartMinY = (minValue * 0.9).clamp(minY, double.infinity);
  chartMaxY = (maxValue * 1.1).clamp(0, maxY);
} else {
  chartMinY = minY;
  chartMaxY = maxY * 0.5;
}

// Pastikan chartMaxY lebih besar dari chartMinY
if (chartMaxY <= chartMinY) {
  chartMaxY = chartMinY + 1.0;
}

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'GRAFIK DATA:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  // Chart type selector
                  PopupMenuButton<int>(
                    icon: Icon(Icons.timeline, size: 20),
                    onSelected: (value) {
                      setState(() => _selectedChartType = value);
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 0,
                        child: Row(
                          children: [
                            Icon(Icons.air, size: 16),
                            SizedBox(width: 8),
                            Text('AQI'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 1,
                        child: Row(
                          children: [
                            Icon(Icons.grain, size: 16),
                            SizedBox(width: 8),
                            Text('PM2.5'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 2,
                        child: Row(
                          children: [
                            Icon(Icons.thermostat, size: 16),
                            SizedBox(width: 8),
                            Text('Suhu'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 8),
                  // Grid toggle
                  IconButton(
                    icon: Icon(
                      _showChartGrid ? Icons.grid_on : Icons.grid_off,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() => _showChartGrid = !_showChartGrid);
                    },
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Time range selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['24h', '7d', '30d'].map((range) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(range),
                    selected: _selectedChartRange == range,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedChartRange = range;
                          _loadHistoricalData();
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: _showChartGrid,
                  drawVerticalLine: false,
                  horizontalInterval: (chartMaxY - chartMinY) / 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: max(1, _historicalData.length / 5),
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= _historicalData.length) return const Text('');
                        final time = _historicalData[value.toInt()].timestamp;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormatter.formatChartTime(time, _selectedChartRange),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (chartMaxY - chartMinY) / 5,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}$unit',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: _historicalData.isNotEmpty ? (_historicalData.length - 1).toDouble() : 1,
                minY: chartMinY,
                maxY: chartMaxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: _getChartColor(),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: _getChartColor(),
                          strokeWidth: 1,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: _getChartColor().withOpacity(0.1),
                    ),
                    gradient: LinearGradient(
                      colors: [
                        _getChartColor(),
                        _getChartColor().withOpacity(0.5),
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Chart legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getChartTitle(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _getChartColor(),
                ),
              ),
              Text(
                '${spots.length} data points',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getChartColor() {
    switch (_selectedChartType) {
      case 0: return Helpers.getAQIColor(_currentRoomData.currentAQI);
      case 1: return Colors.blue;
      case 2: return Colors.orange;
      default: return AppColors.primary;
    }
  }

  String _getChartTitle() {
    switch (_selectedChartType) {
      case 0: return 'Air Quality Index (AQI)';
      case 1: return 'PM2.5 Concentration';
      case 2: return 'Temperature';
      default: return 'Chart';
    }
  }

  Widget _buildLastUpdateInfo() {
  // Ganti dengan:
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
          // Real-time connection indicator
          IconButton(
            icon: Icon(
              _socketConnected ? Icons.wifi : Icons.wifi_off,
              color: _socketConnected ? Colors.green : Colors.grey,
            ),
            onPressed: () {
              if (!_socketConnected) {
                _reconnectSocket();
              } else {
                _socketService.ping();
              }
            },
            tooltip: _socketConnected ? 'Real-time connected' : 'Real-time disconnected',
          ),
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
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: Row(
                  children: [
                    Icon(Icons.info, size: 16),
                    SizedBox(width: 8),
                    Text('Tentang ruangan'),
                  ],
                ),
              ),
              PopupMenuItem(
                child: Row(
                  children: [
                    Icon(Icons.history, size: 16),
                    SizedBox(width: 8),
                    Text('Riwayat lengkap'),
                  ],
                ),
              ),
              PopupMenuItem(
                child: Row(
                  children: [
                    Icon(Icons.share, size: 16),
                    SizedBox(width: 8),
                    Text('Bagikan data'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
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

              SizedBox(height: 24),

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
              const SizedBox(height: 12),
              
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

              // AQI Chart
              _buildAQIChart(),

              SizedBox(height: 24),

              // Health Recommendations
              _buildHealthRecommendations(),

              SizedBox(height: 24),

              // Footer with auto-refresh status
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _socketConnected ? Colors.green : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              _socketConnected ? 'Real-time aktif' : 'Manual refresh',
                              style: TextStyle(
                                fontSize: 12,
                                color: _socketConnected ? Colors.green : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Auto refresh: ${_autoRefreshCountdown}s',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _autoRefreshCountdown / 5,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _socketConnected ? Colors.green : Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}