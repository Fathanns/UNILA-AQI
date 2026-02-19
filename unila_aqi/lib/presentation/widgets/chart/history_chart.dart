import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:unila_aqi/data/models/sensor_data.dart';
import 'package:unila_aqi/data/repositories/history_repository.dart';

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
  bool _isInitialLoad = true;
  String _error = '';
  final ScrollController _scrollController = ScrollController();
  final HistoryRepository _repository = HistoryRepository();
  Timer? _refreshTimer;
  
  // Skala Y-axis otomatis
  double _currentMinY = 0;
  double _currentMaxY = 100;
  bool _hasExtremeValue = false;
  double _extremeValueThreshold = 300; // AQI > 300 dianggap ekstrem
  
  // Parameter options
  final List<String> _parametersRow1 = ['aqi', 'pm25', 'pm10'];
  final List<String> _parametersRow2 = ['co2', 'temperature', 'humidity'];
  final Map<String, String> _parameterLabels = {
    'aqi': 'AQI',
    'pm25': 'PM2.5',
    'pm10': 'PM10',
    'co2': 'CO₂',
    'temperature': 'Suhu',
    'humidity': 'Kelembaban',
  };
  
  // Unit untuk setiap parameter
  
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
    
    // Set up auto-refresh timer setiap 1 menit untuk data hari ini
    if (_selectedDate.year == DateTime.now().year && 
        _selectedDate.month == DateTime.now().month && 
        _selectedDate.day == DateTime.now().day) {
      _startAutoRefresh();
    }
  }
  
  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _loadHistoryData();
      }
    });
  }
  
  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }
  
  @override
  void dispose() {
    _stopAutoRefresh();
    _scrollController.dispose();
    super.dispose();
  }
  
  Future<void> _loadHistoryData() async {
    if (mounted) {
      setState(() {
        if (_isInitialLoad) {
          _isLoading = true;
        }
        _error = '';
      });
    }
    
    try {
      final response = await _repository.getHistoryData(
        roomId: widget.roomId,
        selectedDate: _selectedDate,
        interval: 30,
      );
      
      if (mounted) {
        if (response.success) {
          // Filter data untuk 24 jam terakhir
          final now = DateTime.now();
          final cutoffTime = _selectedDate.year == now.year && 
                            _selectedDate.month == now.month && 
                            _selectedDate.day == now.day
              ? now.subtract(const Duration(hours: 24))
              : DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
          
          final filteredData = response.data
              .where((data) => data.timestamp.isAfter(cutoffTime))
              .toList();
          
          // Sort by timestamp
          filteredData.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          
          setState(() {
            _historyData = filteredData;
            _isInitialLoad = false;
            _isLoading = false;
          });
          
          // Update skala Y-axis berdasarkan data baru
          _updateYAxisScale();
          
          // Auto scroll ke data terbaru setelah data dimuat
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients && _historyData.isNotEmpty) {
              Future.delayed(const Duration(milliseconds: 300), () {
                final maxScroll = _scrollController.position.maxScrollExtent;
                if (maxScroll > 0) {
                  _scrollController.animateTo(
                    maxScroll,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                  );
                }
              });
            }
          });
          
        } else {
          setState(() {
            _error = response.error ?? 'Gagal memuat data';
            _isInitialLoad = false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error: $e';
          _isInitialLoad = false;
          _isLoading = false;
        });
      }
    }
  }
  
  // Fungsi untuk mengupdate skala Y-axis secara otomatis
  void _updateYAxisScale() {
    if (_historyData.isEmpty) {
      _currentMinY = 0;
      _currentMaxY = 100;
      _hasExtremeValue = false;
      return;
    }
    
    double minValue = double.infinity;
    double maxValue = double.negativeInfinity;
    bool hasExtreme = false;
    
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
      if (value > maxValue) maxValue = value;
      
      // Deteksi nilai ekstrem
      if (_selectedParameter == 'aqi' && value > _extremeValueThreshold) {
        hasExtreme = true;
      }
    }
    
    // Simpan nilai maksimum sebelumnya untuk animasi
    
    // Hitung skala dengan logika yang lebih cerdas
    if (hasExtreme) {
      // Jika ada nilai ekstrem, sesuaikan skala untuk menampilkan semuanya
      _currentMinY = 0;
      
      // Tambahkan margin 15% di atas nilai maksimum untuk nilai ekstrem
      double margin = maxValue * 0.15;
      _currentMaxY = (maxValue + margin).ceilToDouble();
      
      // Pastikan skala tidak terlalu kecil untuk nilai normal
      if (_currentMaxY < 100) {
        _currentMaxY = 100;
      }
      
      _hasExtremeValue = true;
    } else {
      // Untuk nilai normal, gunakan margin 20% di atas dan 10% di bawah
      double upperMargin = maxValue * 0.20;
      double lowerMargin = minValue * 0.10;
      
      _currentMinY = (minValue - lowerMargin).floorToDouble();
      if (_currentMinY < 0) _currentMinY = 0;
      
      _currentMaxY = (maxValue + upperMargin).ceilToDouble();
      
      // Pastikan ada rentang minimum yang wajar
      if ((_currentMaxY - _currentMinY) < 20) {
        _currentMaxY = _currentMinY + 20;
      }
      
      _hasExtremeValue = false;
    }
    
    // Batasi skala untuk parameter tertentu
    if (_selectedParameter == 'humidity') {
      // Kelembaban: 0-100%
      _currentMinY = 0;
      _currentMaxY = 100;
    } else if (_selectedParameter == 'temperature') {
      // Suhu: 15-35°C untuk konteks Indonesia
      _currentMinY = 15;
      _currentMaxY = 35;
    }
    
    // Update UI
    if (mounted) {
      setState(() {});
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
      // Stop auto-refresh jika memilih tanggal lain
      if (_refreshTimer != null) {
        _stopAutoRefresh();
      }
      
      setState(() {
        _selectedDate = picked;
        _isInitialLoad = true;
      });
      await _loadHistoryData();
    }
  }
  
  List<FlSpot> _getDataPoints() {
    final spots = <FlSpot>[];
    
    for (int i = 0; i < _historyData.length; i++) {
      final data = _historyData[i];
      final x = i.toDouble();
      
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
      reservedSize: 32,
      interval: 1, // Tampilkan label untuk setiap data point
      getTitlesWidget: (value, meta) {
        if (value < 0 || value >= _historyData.length) return const SizedBox.shrink();
        
        final data = _historyData[value.toInt()];
        final hour = data.timestamp.hour;
        final minute = data.timestamp.minute;
        
        // Tampilkan label untuk setiap data point dengan format HH:mm
        final timeLabel = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        
        // Tampilkan semua label, tapi rotasi untuk menghindari penumpukan
        return Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Transform.rotate(
            angle: 0, // Rotasi 45 derajat
            child: Text(
              timeLabel,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildChart() {
    if (_historyData.isEmpty) {
      return Container(
        height: 340,
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insert_chart_outlined,
              size: 48,
              color: Colors.grey,
            ),
            SizedBox(height: 12),
            Text(
              'Tidak ada data untuk tanggal ini',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    final spots = _getDataPoints();
    final color = _parameterColors[_selectedParameter]!;
    
    // Hitung lebar chart
    final pointWidth = 60.0; // Lebar per titik data
    final chartWidth = _historyData.length * pointWidth;
    final minChartWidth = MediaQuery.of(context).size.width * 0.95;
    final actualChartWidth = chartWidth > minChartWidth ? chartWidth : minChartWidth;
    
    return Container(
      height: 360, // Tinggi untuk menampung label yang di-rotate
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
        children: [
          // Chart Header dengan indikator skala
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grafik ${_parameterLabels[_selectedParameter]}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_hasExtremeValue)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Skala otomatis (ada nilai ekstrem)',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _parameterLabels[_selectedParameter]!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Info skala Y-axis
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_hasExtremeValue)
                  Row(
                    children: [
                      Icon(
                        Icons.warning,
                        size: 12,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Nilai ekstrem terdeteksi',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          // Chart Container
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(top: 8, bottom: 20, right: 4),
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  width: actualChartWidth,
                  child: LineChart(
                    LineChartData(
                      clipData: const FlClipData.all(),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        drawHorizontalLine: true,
                        horizontalInterval: _getHorizontalInterval(),
                        verticalInterval: 1,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.withOpacity(0.1),
                            strokeWidth: 0.5,
                          );
                        },
                        getDrawingVerticalLine: (value) {
                          // Garis vertikal untuk setiap data point
                          return FlLine(
                            color: Colors.grey.withOpacity(0.05),
                            strokeWidth: 0.5,
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
                          axisNameWidget: const Padding(
                            padding: EdgeInsets.only(top: 4.0),
                            
                          ),
                          sideTitles: _getBottomTitles(),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 45,
                            interval: _getLeftAxisInterval(),
                            getTitlesWidget: (value, meta) {
                              // Format nilai Y-axis
                              String valueText;
                              if (value >= 1000) {
                                valueText = '${(value ~/ 1000)}k';
                              } else {
                                valueText = value.toInt().toString();
                              }
                              
                              // Warna khusus untuk nilai tinggi
                              Color textColor = Colors.grey.shade600;
                              if (_selectedParameter == 'aqi' && value >= 300) {
                                textColor = Colors.red;
                              }
                              
                              return Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: Text(
                                  valueText,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: textColor,
                                    fontWeight: value % _getLeftAxisInterval() == 0 
                                        ? FontWeight.w600 
                                        : FontWeight.normal,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: false,
                      ),
                      minX: 0,
                      maxX: _historyData.isNotEmpty ? (_historyData.length - 1).toDouble() : 0,
                      minY: _currentMinY,
                      maxY: _currentMaxY,
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: color,
                          barWidth: 2.2,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              // Dot khusus untuk nilai ekstrem
                              if (_selectedParameter == 'aqi' && spot.y > 300) {
                                return FlDotCirclePainter(
                                  radius: 4.0,
                                  color: Colors.red,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                );
                              }
                              
                              return FlDotCirclePainter(
                                radius: 2.5,
                                color: color,
                                strokeWidth: 1.5,
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
                                color.withOpacity(0.15),
                                color.withOpacity(0.05),
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
                          tooltipRoundedRadius: 6,
                          tooltipPadding: const EdgeInsets.all(10),
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          maxContentWidth: 150,
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
                              
                              // Tooltip hanya menampilkan waktu dan parameter yang dipilih
                              String valueText;
                              switch (_selectedParameter) {
                                case 'aqi':
                                  valueText = '${data.aqi}';
                                  break;
                                case 'pm25':
                                  valueText = '${data.pm25.toStringAsFixed(1)}';
                                  break;
                                case 'pm10':
                                  valueText = '${data.pm10.toStringAsFixed(1)}';
                                  break;
                                case 'co2':
                                  valueText = '${data.co2.round()}';
                                  break;
                                case 'temperature':
                                  valueText = '${data.temperature.toStringAsFixed(1)}';
                                  break;
                                case 'humidity':
                                  valueText = '${data.humidity.round()}';
                                  break;
                                default:
                                  valueText = '${spot.y.toStringAsFixed(1)}';
                              }
                              
                              // Tambahkan unit jika diperlukan
                              if (_selectedParameter == 'pm25' || _selectedParameter == 'pm10') {
                                valueText = '$valueText μg/m³';
                              } else if (_selectedParameter == 'co2') {
                                valueText = '$valueText ppm';
                              } else if (_selectedParameter == 'temperature') {
                                valueText = '$valueText°C';
                              } else if (_selectedParameter == 'humidity') {
                                valueText = '$valueText%';
                              }
                              
                              // Tambahkan indikator ekstrem
                              String extremeIndicator = '';
                              if (_selectedParameter == 'aqi' && data.aqi > 300) {
                                extremeIndicator = ' ⚠️';
                              }
                              
                              final tooltipText = '$time\n${_parameterLabels[_selectedParameter]!}: $valueText$extremeIndicator';
                              
                              return LineTooltipItem(
                                tooltipText,
                                TextStyle(
                                  color: data.aqi > 300 ? Colors.red : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 11,
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
          ),
        ],
      ),
    );
  }
  
  double _getHorizontalInterval() {
    final range = _currentMaxY - _currentMinY;
    
    if (range <= 50) return 10;
    if (range <= 100) return 20;
    if (range <= 200) return 40;
    if (range <= 500) return 100;
    if (range <= 1000) return 200;
    return 500;
  }
  
  double _getLeftAxisInterval() {
    final range = _currentMaxY - _currentMinY;
    
    if (range <= 20) return 5;
    if (range <= 50) return 10;
    if (range <= 100) return 20;
    if (range <= 200) return 40;
    if (range <= 500) return 100;
    if (range <= 1000) return 200;
    return 500;
  }
  
  Widget _buildParameterSelector() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih Parameter:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          
          // Baris pertama: AQI, PM2.5, PM10
          Container(
            height: 36,
            margin: const EdgeInsets.only(bottom: 6),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _parametersRow1.length,
              itemBuilder: (context, index) {
                final parameter = _parametersRow1[index];
                final isSelected = _selectedParameter == parameter;
                final color = _parameterColors[parameter]!;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedParameter = parameter;
                      // Update skala ketika parameter berubah
                      _updateYAxisScale();
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? color : color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? color : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _parameterLabels[parameter]!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : color,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Baris kedua: CO2, Suhu, Kelembaban
          Container(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _parametersRow2.length,
              itemBuilder: (context, index) {
                final parameter = _parametersRow2[index];
                final isSelected = _selectedParameter == parameter;
                final color = _parameterColors[parameter]!;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedParameter = parameter;
                      // Update skala ketika parameter berubah
                      _updateYAxisScale();
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? color : color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? color : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _parameterLabels[parameter]!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : color,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDateSelector() {
    final isToday = _selectedDate.year == DateTime.now().year && 
                    _selectedDate.month == DateTime.now().month && 
                    _selectedDate.day == DateTime.now().day;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
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
              Text(
                isToday ? 'HARI INI' : DateFormat('EEEE').format(_selectedDate).toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('dd MMM yyyy').format(_selectedDate),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (_historyData.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.08),
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
                        '${_historyData.length} titik',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _selectDate(context),
                icon: const Icon(Icons.calendar_month, size: 20),
                iconSize: 18,
                padding: const EdgeInsets.all(6),
                tooltip: 'Pilih tanggal',
              ),
              IconButton(
                onPressed: _loadHistoryData,
                icon: const Icon(Icons.refresh, size: 20),
                iconSize: 18,
                padding: const EdgeInsets.all(6),
                tooltip: 'Refresh data',
              ),
            ],
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
        
        if (_isLoading && _isInitialLoad)
          Container(
            height: 360,
            alignment: Alignment.center,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(height: 12),
                Text(
                  'Memuat data history...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          )
        else if (_error.isNotEmpty)
          Container(
            height: 360,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 40,
                  color: Colors.red,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    _error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadHistoryData,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Coba Lagi',
                    style: TextStyle(fontSize: 12),
                  ),
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