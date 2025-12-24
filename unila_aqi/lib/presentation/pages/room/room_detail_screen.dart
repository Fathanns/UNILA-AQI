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
  List<SensorDataPoint> _historicalData = [];
  bool _isLoadingHistory = false;
  String _selectedChartRange = '24h';
  Timer? _autoRefreshTimer;
  int _autoRefreshCountdown = 30;
  bool _isRefreshing = false;
  bool _isMounted = false;

Future<void> _loadHistoricalData() async {
  if (!_isMounted) return;
  
  setState(() => _isLoadingHistory = true);
  
  try {
    final response = await _apiService.getSensorDataHistory(
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
  } finally {
    if (_isMounted) {
      setState(() => _isLoadingHistory = false);
    }
  }
}

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    
    // Delay auto refresh start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isMounted) {
        _loadHistoricalData();
        _startAutoRefresh();
      }
    });
  }

  @override
  void dispose() {
    _isMounted = false;
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
            _autoRefreshCountdown = 30;
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
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));
    
    if (_isMounted) {
      setState(() => _isRefreshing = false);
      Helpers.showSnackBar(context, 'Data diperbarui');
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
  final aqi = widget.room.currentAQI;
  final aqiColor = Helpers.getAQIColor(aqi);
  final recommendations = Helpers.getDetailedRecommendations(widget.room);
  
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
  final data = widget.room.currentData;
  
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

  // Widget _buildCheckItem(String text, bool isGood) {
  //   return Padding(
  //     padding: const EdgeInsets.only(bottom: 6),
  //     child: Row(
  //       children: [
  //         Icon(
  //           isGood ? Icons.check_circle : Icons.warning,
  //           color: isGood ? AppColors.success : AppColors.warning,
  //           size: 16,
  //         ),
  //         const SizedBox(width: 8),
  //         Expanded(
  //           child: Text(
  //             text,
  //             style: TextStyle(
  //               color: isGood ? AppColors.success : AppColors.warning,
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildAQIChart() {
  if (_isLoadingHistory) {
    return Container(
      height: 250,
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
  
  if (_historicalData.isEmpty) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      child: const Center(
        child: Text('Tidak ada data historis tersedia'),
      ),
    );
  }
  
  // Prepare chart data
  final spots = _historicalData.asMap().entries.map((entry) {
    final index = entry.key;
    final data = entry.value;
    return FlSpot(index.toDouble(), data.aqi.toDouble());
  }).toList();
  
  // Find min and max for Y axis
  final aqiValues = _historicalData.map((d) => d.aqi).toList();
  final minY = (aqiValues.reduce(min) * 0.8).toDouble();
  final maxY = (aqiValues.reduce(max) * 1.2).toDouble();
  
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
            const Text(
              'GRAFIK AQI:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: ['24h', '7d', '30d'].map((range) {
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
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
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: (maxY - minY) / 5,
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: _historicalData.length > 12 ? 2 : 1,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= _historicalData.length) return const Text('');
                      final time = _historicalData[value.toInt()].timestamp;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          DateFormatter.formatChartTime(time, _selectedChartRange),
                          style: const TextStyle(
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
                    interval: (maxY - minY) / 5,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(
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
              maxX: _historicalData.length > 0 ? (_historicalData.length - 1).toDouble() : 1,
              minY: minY,
              maxY: maxY,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Helpers.getAQIColor(widget.room.currentAQI),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Helpers.getAQIColor(widget.room.currentAQI).withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final aqiColor = Helpers.getAQIColor(widget.room.currentAQI);
    final aqiLabel = Helpers.getAQILabel(widget.room.currentAQI);
    final timeAgo = Helpers.formatTimeAgo(widget.room.currentData.updatedAt);

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
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Room Info
              Center(
                child: Column(
                  children: [
                    Text(
                      widget.room.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      widget.room.buildingName,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // AQI Display
              Center(
                child: Container(
                  width: 180,
                  height: 180,
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
                        widget.room.currentAQI.toString(),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          color: aqiColor,
                        ),
                      ),
                      Text(
                        'AQI',
                        style: TextStyle(
                          fontSize: 16,
                          color: aqiColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: aqiColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          aqiLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
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
                    widget.room.currentData.pm25.toStringAsFixed(1),
                    Helpers.getPM25Status(widget.room.currentData.pm25),
                    Helpers.getPM25Color(widget.room.currentData.pm25),
                  ),
                  _buildParameterCard(
                    'PM10',
                    widget.room.currentData.pm10.toStringAsFixed(1),
                    Helpers.getPM25Status(widget.room.currentData.pm10),
                    Helpers.getPM25Color(widget.room.currentData.pm10),
                  ),
                  _buildParameterCard(
                    'CO₂',
                    '${widget.room.currentData.co2.round()}',
                    Helpers.getCO2Status(widget.room.currentData.co2),
                    Helpers.getCO2Color(widget.room.currentData.co2),
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
                    '${widget.room.currentData.temperature.toStringAsFixed(1)}°C',
                    Helpers.getTemperatureStatus(widget.room.currentData.temperature),
                    Helpers.getTemperatureColor(widget.room.currentData.temperature),
                  ),
                  _buildParameterCard(
                    'KELEMBABAN',
                    '${widget.room.currentData.humidity.round()}%',
                    Helpers.getHumidityStatus(widget.room.currentData.humidity),
                    Helpers.getHumidityColor(widget.room.currentData.humidity),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // AQI Chart
              _buildAQIChart(),
              const SizedBox(height: 24),
              // Health Recommendations
              _buildHealthRecommendations(),
              const SizedBox(height: 24),
              // Footer
              Center(
                child: Text(
                  'Update: $timeAgo | Auto refresh: ${_autoRefreshCountdown}s',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}