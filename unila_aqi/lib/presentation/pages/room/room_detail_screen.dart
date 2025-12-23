import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../data/models/room.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/constants/colors.dart';

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
  String _selectedChartRange = '24h';
  Timer? _autoRefreshTimer;
  int _autoRefreshCountdown = 30;
  bool _isRefreshing = false;
  bool _isMounted = false;
  
  // Sample chart data
  final List<FlSpot> _chartData = [
    FlSpot(0, 25),
    FlSpot(2, 35),
    FlSpot(4, 40),
    FlSpot(6, 60),
    FlSpot(8, 75),
    FlSpot(10, 52),
    FlSpot(12, 45),
    FlSpot(14, 65),
    FlSpot(16, 80),
    FlSpot(18, 70),
    FlSpot(20, 55),
    FlSpot(22, 52),
    FlSpot(24, 50),
  ];

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    
    // Delay auto refresh start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isMounted) {
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
    final recommendations = Helpers.getAQIHealthMessage(aqi);
    
    List<String> warnings = [];
    
    // Add specific warnings based on parameters
    if (widget.room.currentData.pm25 > 35.4) {
      warnings.add('PM2.5 tinggi! Gunakan masker');
    }
    if (widget.room.currentData.pm10 > 154) {
      warnings.add('PM10 tinggi! Kurangi aktivitas luar');
    }
    if (widget.room.currentData.co2 > 1000) {
      warnings.add('CO₂ tinggi! Perbaiki ventilasi');
    }
    if (widget.room.currentData.temperature > 28) {
      warnings.add('Suhu panas');
    }
    if (widget.room.currentData.humidity > 70) {
      warnings.add('Kelembaban tinggi');
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
            children: [
              Icon(
                Icons.health_and_safety,
                color: aqiColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'REKOMENDASI & PERINGATAN:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: aqiColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // AQI Status
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: aqiColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AQI dalam kategori ${Helpers.getAQILabel(aqi)}',
                  style: TextStyle(
                    color: aqiColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Parameter Checks
          if (widget.room.currentData.pm25 <= 12)
            _buildCheckItem('PM2.5 dalam batas aman', true),
          if (widget.room.currentData.pm10 <= 54)
            _buildCheckItem('PM10 dalam batas aman', true),
          if (widget.room.currentData.co2 <= 600)
            _buildCheckItem('CO₂ dalam batas normal', true),
          if (widget.room.currentData.temperature >= 22 && widget.room.currentData.temperature <= 26)
            _buildCheckItem('Suhu ruangan ideal', true),
          if (widget.room.currentData.humidity >= 40 && widget.room.currentData.humidity <= 60)
            _buildCheckItem('Kelembaban ideal', true),
          // Warnings
          for (final warning in warnings)
            _buildCheckItem(warning, false),
          const SizedBox(height: 12),
          // General Recommendation
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saran:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  recommendations,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String text, bool isGood) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            isGood ? Icons.check_circle : Icons.warning,
            color: isGood ? AppColors.success : AppColors.warning,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isGood ? AppColors.success : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAQIChart() {
    final minY = _chartData.map((spot) => spot.y).reduce((a, b) => a < b ? a : b) - 10;
    final maxY = _chartData.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) + 10;

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
                'GRAFIK AQI 24 JAM:',
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
                        setState(() {
                          _selectedChartRange = range;
                        });
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
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 24,
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: _chartData,
                    isCurved: true,
                    color: Helpers.getAQIColor(widget.room.currentAQI),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Helpers.getAQIColor(widget.room.currentAQI).withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['00', '06', '12', '18', '24'].map((hour) {
              return Text(
                hour,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              );
            }).toList(),
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
                    '${widget.room.currentData.pm25.toStringAsFixed(1)}',
                    Helpers.getPM25Status(widget.room.currentData.pm25),
                    Helpers.getPM25Color(widget.room.currentData.pm25),
                  ),
                  _buildParameterCard(
                    'PM10',
                    '${widget.room.currentData.pm10.toStringAsFixed(1)}',
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