import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:unila_aqi/data/models/sensor_data.dart';

class HistoryChart extends StatefulWidget {
  final String roomId;
  final String roomName;
  final String buildingName;
  
  const HistoryChart({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.buildingName,
  });

  @override
  _HistoryChartState createState() => _HistoryChartState();
}

class _HistoryChartState extends State<HistoryChart> {
  // State variables
  List<SensorData> _historyData = [];
  DateTime _selectedDate = DateTime.now();
  String _selectedParameter = 'aqi';
  bool _isLoading = false;
  String _error = '';
  final ScrollController _scrollController = ScrollController();
  
  // Parameter options
  final List<String> _parameters = ['aqi', 'pm25', 'pm10', 'co2', 'temperature', 'humidity'];
  final Map<String, String> _parameterLabels = {
    'aqi': 'AQI',
    'pm25': 'PM2.5',
    'pm10': 'PM10',
    'co2': 'CO₂',
    'temperature': 'Suhu',
    'humidity': 'Kelembaban',
  };
  
  // Color for each parameter
  final Map<String, Color> _parameterColors = {
    'aqi': Colors.blue,
    'pm25': Colors.red,
    'pm10': Colors.orange,
    'co2': Colors.green,
    'temperature': Colors.purple,
    'humidity': Colors.teal,
  };
  
  @override
  void initState() {
    super.initState();
    _loadHistoryData();
    // Auto scroll ke data terbaru setelah data dimuat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  Future<void> _loadHistoryData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }
    
    try {
      await _generateSampleData();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading data: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Helper function untuk mendapatkan kategori AQI
  String _getAQICategory(int aqi) {
    if (aqi <= 50) return 'baik';
    if (aqi <= 100) return 'sedang';
    if (aqi <= 150) return 'tidak_sehat';
    if (aqi <= 200) return 'sangat_tidak_sehat';
    if (aqi <= 300) return 'berbahaya';
    return 'error';
  }
  
  Future<void> _generateSampleData() async {
    // Simulasi data dari 00:00 sampai 23:30 setiap 30 menit
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day);
    final data = <SensorData>[];
    
    for (int hour = 0; hour < 24; hour++) {
      for (int minute = 0; minute < 60; minute += 30) {
        final timestamp = startDate.add(Duration(hours: hour, minutes: minute));
        
        final randomFactor = (DateTime.now().millisecond % 20) - 10;
        
        final aqiValue = (30 + hour * 2 + randomFactor).toInt();
        
        final sensorData = SensorData(
          id: '${timestamp.millisecondsSinceEpoch}',
          roomId: widget.roomId,
          roomName: widget.roomName,
          buildingName: widget.buildingName,
          aqi: aqiValue,
          pm25: 15.0 + hour * 1.5 + randomFactor.toDouble(),
          pm10: 25.0 + hour * 2.0 + randomFactor.toDouble(),
          co2: 400.0 + hour * 20.0 + randomFactor * 5.0,
          temperature: 22.0 + hour * 0.5 + randomFactor * 0.2,
          humidity: 50.0 + hour * 1.0 + randomFactor * 2.0,
          category: _getAQICategory(aqiValue),
          timestamp: timestamp,
        );
        
        data.add(sensorData);
      }
    }
    
    if (mounted) {
      setState(() {
        _historyData = data;
      });
    }
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadHistoryData();
    }
  }
  
  List<FlSpot> _getDataPoints() {
    final spots = <FlSpot>[];
    
    for (int i = 0; i < _historyData.length; i++) {
      final data = _historyData[i];
      final x = i.toDouble(); // Menggunakan index sebagai x untuk spacing konsisten
      
      double y;
      switch (_selectedParameter) {
        case 'aqi':
          y = data.aqi.toDouble();
          break;
        case 'pm25':
          y = data.pm25;
          break;
        case 'pm10':
          y = data.pm10;
          break;
        case 'co2':
          y = data.co2;
          break;
        case 'temperature':
          y = data.temperature;
          break;
        case 'humidity':
          y = data.humidity;
          break;
        default:
          y = 0;
      }
      
      spots.add(FlSpot(x, y));
    }
    
    return spots;
  }
  
  SideTitles _getBottomTitles() {
    return SideTitles(
      showTitles: true,
      reservedSize: 30,
      interval: 2, // Tampilkan setiap 2 data point (setiap jam)
      getTitlesWidget: (value, meta) {
        if (value < 0 || value >= _historyData.length) return const SizedBox.shrink();
        
        final data = _historyData[value.toInt()];
        final hour = data.timestamp.hour;
        final minute = data.timestamp.minute;
        
        // Hanya tampilkan label setiap jam (00 menit)
        if (minute == 0) {
          final hourLabel = hour == 0 ? '00' : hour.toString().padLeft(2, '0');
          return Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              '$hourLabel:00',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
  
  Widget _buildChart() {
    final spots = _getDataPoints();
    final color = _parameterColors[_selectedParameter]!;
    
    // Hitung lebar chart berdasarkan jumlah data
    final chartWidth = _historyData.length * 60.0;
    final minChartWidth = MediaQuery.of(context).size.width * 1.5;
    final actualChartWidth = chartWidth > minChartWidth ? chartWidth : minChartWidth;
    
    return Container(
      height: 350,
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
        children: [
          // Chart Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Grafik ${_parameterLabels[_selectedParameter]}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
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
                      _parameterLabels[_selectedParameter]!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Scrollable Chart Area
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: Container(
                width: actualChartWidth,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      drawHorizontalLine: false, // HAPUS: garis horizontal Y
                      horizontalInterval: 20,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.transparent, // HAPUS: transparan
                          strokeWidth: 0,
                        );
                      },
                      getDrawingVerticalLine: (value) {
                        if (value % 2 == 0) { // Setiap 2 data point (setiap jam)
                          return FlLine(
                            color: Colors.grey.withOpacity(0.1),
                            strokeWidth: 0.5,
                          );
                        }
                        return FlLine(
                          color: Colors.transparent,
                          strokeWidth: 0,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: _getBottomTitles(),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: false, // HAPUS: label sumbu Y
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: false, // HAPUS: border chart
                    ),
                    minX: 0,
                    maxX: _historyData.length > 0 ? (_historyData.length - 1).toDouble() : 0,
                    minY: _getMinY(),
                    maxY: _getMaxY(),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: color,
                        barWidth: 2.5,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 3.5,
                              color: color,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              color.withOpacity(0.3),
                              color.withOpacity(0.1),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        tooltipBgColor: Colors.white,
                        tooltipRoundedRadius: 8,
                        tooltipPadding: const EdgeInsets.all(12),
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        maxContentWidth: MediaQuery.of(context).size.width * 0.7,
                        getTooltipItems: (List<LineBarSpot> touchedSpots) {
                          return touchedSpots.map((spot) {
                            final index = spot.spotIndex;
                            if (index < 0 || index >= _historyData.length) {
                              return null;
                            }
                            
                            final data = _historyData[index];
                            final hour = data.timestamp.hour;
                            final minute = data.timestamp.minute;
                            final time = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
                            
                            // Get all values for this time point
                            final values = {
                              'AQI': '${data.aqi}',
                              'PM2.5': '${data.pm25.toStringAsFixed(1)} μg/m³',
                              'PM10': '${data.pm10.toStringAsFixed(1)} μg/m³',
                              'CO₂': '${data.co2.round()} ppm',
                              'Suhu': '${data.temperature.toStringAsFixed(1)}°C',
                              'Kelembaban': '${data.humidity.round()}%',
                            };
                            
                            return LineTooltipItem(
                              'Waktu: $time\n\n${values.entries.map((e) => '${e.key}: ${e.value}').join('\n')}',
                              const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            );
                          }).where((element) => element != null).cast<LineTooltipItem>().toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }
  
  double _getMinY() {
    if (_historyData.isEmpty) return 0.0;
    
    double minValue = double.infinity;
    for (var data in _historyData) {
      double value;
      switch (_selectedParameter) {
        case 'aqi':
          value = data.aqi.toDouble();
          break;
        case 'pm25':
          value = data.pm25;
          break;
        case 'pm10':
          value = data.pm10;
          break;
        case 'co2':
          value = data.co2;
          break;
        case 'temperature':
          value = data.temperature;
          break;
        case 'humidity':
          value = data.humidity;
          break;
        default:
          value = 0.0;
      }
      if (value < minValue) minValue = value;
    }
    
    return minValue - (minValue * 0.1);
  }
  
  double _getMaxY() {
    if (_historyData.isEmpty) return 100.0;
    
    double maxValue = double.negativeInfinity;
    for (var data in _historyData) {
      double value;
      switch (_selectedParameter) {
        case 'aqi':
          value = data.aqi.toDouble();
          break;
        case 'pm25':
          value = data.pm25;
          break;
        case 'pm10':
          value = data.pm10;
          break;
        case 'co2':
          value = data.co2;
          break;
        case 'temperature':
          value = data.temperature;
          break;
        case 'humidity':
          value = data.humidity;
          break;
        default:
          value = 0.0;
      }
      if (value > maxValue) maxValue = value;
    }
    
    return maxValue + (maxValue * 0.1);
  }
  
  Widget _buildParameterSelector() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _parameters.length,
        itemBuilder: (context, index) {
          final parameter = _parameters[index];
          final isSelected = _selectedParameter == parameter;
          final color = _parameterColors[parameter]!;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedParameter = parameter;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? color : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected ? color : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _parameterLabels[parameter]!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : color,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildDateSelector() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
             
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () => _selectDate(context),
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Pilih tanggal lain',
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDateSelector(),
        
        _buildParameterSelector(),
        
        if (_isLoading)
          Container(
            height: 350,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          )
        else if (_error.isNotEmpty)
          Container(
            height: 350,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  _error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadHistoryData,
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          )
        else if (_historyData.isEmpty)
          Container(
            height: 350,
            alignment: Alignment.center,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.insert_chart_outlined,
                  size: 48,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'Tidak ada data history untuk tanggal ini',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          )
        else
          _buildChart(),
      ],
    );
  }
}