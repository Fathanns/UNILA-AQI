// aqi_history_chart.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/models/historical_data.dart';
import '../../core/utils/helpers.dart';
import '../../core/services/api_service.dart';

class AQIHistoryChart extends StatefulWidget {
  final String roomId;

  const AQIHistoryChart({
    Key? key,
    required this.roomId,
  }) : super(key: key);

  @override
  State<AQIHistoryChart> createState() => _AQIHistoryChartState();
}

class _AQIHistoryChartState extends State<AQIHistoryChart> {
  final ApiService _apiService = ApiService();
  List<HistoricalData> _historicalData = [];
  String _selectedRange = '24h'; // '24h' or '30d'
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadHistoricalData();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    // Auto refresh every 10 minutes for 24h view
    _autoRefreshTimer = Timer.periodic(Duration(minutes: 10), (timer) {
      if (_selectedRange == '24h' && mounted) {
        _loadHistoricalData();
      }
    });
  }

  Future<void> _loadHistoricalData() async {
  if (!mounted) return;

  setState(() => _isLoading = true);

  try {
    print('📊 Loading historical data for room: ${widget.roomId}, range: $_selectedRange');
    
    // Gunakan ApiService langsung
    final response = _selectedRange == '24h'
        ? await _apiService.getHistoricalData24h(widget.roomId)
        : await _apiService.getHistoricalData30d(widget.roomId);

    print('📊 API Response: ${response['success']}, data count: ${response['data']?.length ?? 0}');

    if (mounted && response['success'] == true) {
      final List<dynamic> data = response['data'] ?? [];
      
      print('📊 Processing ${data.length} data points');
      
      setState(() {
        _historicalData = data
            .map((json) => HistoricalData.fromJson(json))
            .toList();
      });

      print('📊 Chart data loaded: ${_historicalData.length} points');
      
      // Scroll to most recent data
      if (_historicalData.isNotEmpty && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 500),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } else {
      print('❌ Failed to load historical data: ${response['message']}');
    }
  } catch (e) {
    print('❌ Error loading historical data: $e');
    print('❌ Stack trace: ${e.toString()}');
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

  Widget _buildChart() {
    if (_historicalData.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada data historis',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        width: _calculateChartWidth(),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey[300],
                  strokeWidth: 0.5,
                );
              },
              getDrawingVerticalLine: (value) {
                return FlLine(
                  color: Colors.grey[300],
                  strokeWidth: 0.5,
                );
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < _historicalData.length) {
                      final data = _historicalData[index];
                      if (_selectedRange == '24h') {
                        // Show only even hours for 24h
                        if (data.hour != null && data.hour! % 2 == 0) {
                          return Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              '${data.hour!.toString().padLeft(2, '0')}.00',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          );
                        }
                      } else {
                        // Show date for 30d
                        return Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            data.displayDate ?? '',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        );
                      }
                    }
                    return Text('');
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.grey[300]!),
            ),
            minY: 0,
            maxY: _calculateMaxY(),
            lineBarsData: [
              LineChartBarData(
                spots: _historicalData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  return FlSpot(index.toDouble(), data.aqi);
                }).toList(),
                isCurved: true,
                color: Colors.blue,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: Helpers.getAQIColor(spot.y.toInt()),
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.withOpacity(0.3),
                      Colors.blue.withOpacity(0.1),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                tooltipBgColor: Colors.white,
                tooltipRoundedRadius: 8,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((touchedSpot) {
                    final index = touchedSpot.spotIndex;
                    if (index >= 0 && index < _historicalData.length) {
                      final data = _historicalData[index];
                      return LineTooltipItem(
                        data.getTooltipText(),
                        TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    }
                    return LineTooltipItem('', TextStyle());
                  }).toList();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _calculateChartWidth() {
    if (_selectedRange == '24h') {
      // 24 hours with 10-min intervals = 144 points
      // Each point takes 10px width
      return max(_historicalData.length * 10.0, MediaQuery.of(context).size.width);
    } else {
      // 30 days, each day takes 30px width
      return max(_historicalData.length * 30.0, MediaQuery.of(context).size.width);
    }
  }

  double _calculateMaxY() {
    if (_historicalData.isEmpty) return 300;
    
    final maxAqi = _historicalData.map((d) => d.aqi).reduce((a, b) => a > b ? a : b);
    // Add some padding
    return maxAqi * 1.2;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and range selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'History AQI',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              Row(
                children: [
                  _buildRangeButton('24h', '24 Jam'),
                  SizedBox(width: 8),
                  _buildRangeButton('30d', '30 Hari'),
                ],
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Range info
          Text(
            _selectedRange == '24h' 
                ? 'Data per 10 menit (24 jam terakhir)'
                : 'Rata-rata harian (30 hari terakhir)',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          
          SizedBox(height: 16),
          
          // Chart container
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _buildChart(),
          ),
          
          SizedBox(height: 8),
          
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Nilai AQI',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(width: 16),
              Icon(Icons.touch_app, size: 14, color: Colors.grey),
              SizedBox(width: 4),
              Text(
                'Ketuk titik untuk detail',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 8),
          
          // Scroll hint for 24h
          if (_selectedRange == '24h' && _historicalData.length > 12)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.swipe_left, size: 14, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  'Geser ke kiri untuk melihat data sebelumnya',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRangeButton(String range, String label) {
    final isSelected = _selectedRange == range;
    return InkWell(
      onTap: () {
        if (!isSelected) {
          setState(() => _selectedRange = range);
          _loadHistoricalData();
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
}