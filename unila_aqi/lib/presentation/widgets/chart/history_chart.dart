import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:unila_aqi/core/services/api_service.dart';
import 'package:unila_aqi/core/utils/helpers.dart';
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

  // FOV config — 8 titik per viewport
  static const int _pointsInView = 8;
  static const double _containerPadding = 16.0;

  // Parameter options
  // Parameter opsional (so2, o3, no2) hanya dimasukkan bila ada data.
  final List<String> _baseParameters = [
    'aqi',
    'pm25',
    'pm10',
    'co',
    'temperature',
    'humidity',
  ];

  final List<String> _optionalParameters = ['so2', 'o3', 'no2'];

  final Map<String, String> _parameterLabels = {
    'aqi': 'AQI',
    'pm25': 'PM2.5',
    'pm10': 'PM10',
    'co': 'CO',
    'so2': 'SO2',
    'o3': 'O3',
    'no2': 'NO2',
    'temperature': 'Suhu',
    'humidity': 'Kelembaban',
  };

  // Color for each parameter
  final Map<String, Color> _parameterColors = {
    'aqi': Colors.blue,
    'pm25': Colors.red,
    'pm10': Colors.orange,
    'co': Colors.green,
    'so2': Colors.brown,
    'o3': Colors.cyan,
    'no2': Colors.indigo,
    'temperature': Colors.purple,
    'humidity': Colors.teal,
  };

  @override
  void initState() {
    super.initState();
    _loadHistoryData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500),
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

  // ============================================================
  // HELPER: ambil nilai parameter dari satu titik data.
  // Mengembalikan null bila parameter tidak tersedia (IoT parsial).
  // ============================================================
  double? _valueFor(SensorData data, String parameter) {
    switch (parameter) {
      case 'aqi':
        return data.aqi.toDouble();
      case 'pm25':
        return data.pm25;
      case 'pm10':
        return data.pm10;
      case 'co':
        return data.co;
      case 'so2':
        return data.so2;
      case 'o3':
        return data.o3;
      case 'no2':
        return data.no2;
      case 'temperature':
        return data.temperature;
      case 'humidity':
        return data.humidity;
      default:
        return null;
    }
  }

  // ============================================================
  // Parameter yang boleh dipilih: base + optional (hanya yang ada data)
  // ============================================================
  List<String> get _availableParameters {
    final optional = _optionalParameters.where((p) {
      return _historyData.any((d) => _valueFor(d, p) != null);
    }).toList();
    return [..._baseParameters, ...optional];
  }

  Future<void> _loadHistoryData() async {
    if (!mounted) return;

    final hadData = _historyData.isNotEmpty;

    setState(() {
      // Spinner hanya saat belum ada data sama sekali
      _isLoading = !hadData;
      _error = '';
    });

    bool failed = false;
    bool isNetworkFailure = false;

    try {
      final dateStr =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

      final response =
          await ApiService().getSensorHistory(widget.roomId, dateStr);

      if (!mounted) return;

      if (response is Map && response['success'] == true) {
        final List<dynamic> data = response['data'] ?? [];
        final parsed = data
            .map((json) =>
                SensorData.fromJson(Map<String, dynamic>.from(json)))
            .toList();

        setState(() {
          _historyData = parsed;

          // Pastikan parameter terpilih masih tersedia.
          // Jika tidak (mis. sebelumnya user pilih SO2, lalu pindah
          // tanggal yang datanya tidak punya SO2), fallback ke AQI.
          if (!_availableParameters.contains(_selectedParameter)) {
            _selectedParameter = 'aqi';
          }
        });
      } else {
        failed = true;
        final errStr =
            (response is Map) ? (response['error']?.toString() ?? '') : '';
        isNetworkFailure = Helpers.isNetworkError(errStr);
      }
    } catch (e) {
      failed = true;
      isNetworkFailure = Helpers.isNetworkError(e);
    }

    if (!mounted) return;

    if (failed) {
      // ❗ TIDAK generate sample baru.
      // Data lama (_historyData) tetap dipakai.
      // UI error penuh hanya muncul kalau memang belum pernah ada data.
      if (!hadData) {
        setState(() {
          _error = isNetworkFailure
              ? 'Tidak dapat memuat data grafik karena server tidak dapat dihubungi.'
              : 'Gagal memuat data grafik.';
        });
      }

      if (isNetworkFailure) {
        Helpers.showServerError(context);
      } else {
        Helpers.showSnackBar(
          context,
          'Gagal memuat data grafik',
          isError: true,
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // FIXED: bungkus dengan try-catch. showDatePicker dapat melempar
  // (mis. context tidak valid saat widget sudah unmounted).
  Future<void> _selectDate(BuildContext context) async {
    try {
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
    } catch (e) {
      debugPrint('❌ Date picker error: $e');
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Gagal membuka pemilih tanggal',
          isError: true,
        );
      }
    }
  }

  List<FlSpot> _getDataPoints() {
    final spots = <FlSpot>[];

    for (int i = 0; i < _historyData.length; i++) {
      final data = _historyData[i];
      final y = _valueFor(data, _selectedParameter);
      if (y == null) continue;
      spots.add(FlSpot(i.toDouble(), y));
    }

    return spots;
  }

  // FIXED: interval diubah dari 2 → 1 agar getTitlesWidget dipanggil
  // untuk SETIAP titik. Penyaringan label dilakukan di dalam widget
  // berdasarkan minute == 0 (jam genap: 14:00, 15:00, 16:00).
  //
  // Dengan cara ini, label tetap muncul dengan benar meskipun titik
  // pertama bukan berada di menit :00 (mis. chart dibuka saat 14:30,
  // maka titik pertama adalah 14:30 → label pertama di 15:00).
  SideTitles _getBottomTitles() {
    return SideTitles(
      showTitles: true,
      reservedSize: 30,
      interval: 1,
      getTitlesWidget: (value, meta) {
        // Hanya untuk nilai x yang berupa bilangan bulat (indeks valid)
        final index = value.toInt();
        if (value != index.toDouble()) return const SizedBox.shrink();
        if (index < 0 || index >= _historyData.length) {
          return const SizedBox.shrink();
        }

        final data = _historyData[index];
        final hour = data.timestamp.hour;
        final minute = data.timestamp.minute;

        // FIXED: hanya tampilkan label di jam genap (minute == 0).
        // Titik di menit :30 (14:30, 15:30, ...) tidak diberi label.
        if (minute != 0) return const SizedBox.shrink();

        final hourLabel = hour.toString().padLeft(2, '0');
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
      },
    );
  }

  Widget _buildChart() {
    final spots = _getDataPoints();
    final color = _parameterColors[_selectedParameter]!;

    // FIXED: FOV 8 titik per viewport.
    //   pointSpacing = (lebar layar − padding container) / 8
    //   chartWidth   = jumlah titik × pointSpacing
    //   minimal      = lebar viewport (agar chart tidak lebih sempit dari layar)
    //
    // Contoh pada layar 400px:
    //   availableViewport = 400 − 32 = 368
    //   pointSpacing      = 368 / 8 = 46px
    //   48 titik (24 jam) → chartWidth = 48 × 46 = 2208px
    //   viewport 368px    → menampilkan 368/46 = 8 titik
    final screenWidth = MediaQuery.of(context).size.width;
    final availableViewport =
        screenWidth - (_containerPadding * 2);
    final pointSpacing = availableViewport / _pointsInView;

    final calculatedWidth = _historyData.length * pointSpacing;
    final actualChartWidth = calculatedWidth > availableViewport
        ? calculatedWidth
        : availableViewport;

    return Container(
      height: 350,
      padding: const EdgeInsets.all(_containerPadding),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      drawHorizontalLine: false,
                      horizontalInterval: 20,
                      getDrawingHorizontalLine: (value) {
                        return const FlLine(
                          color: Colors.transparent,
                          strokeWidth: 0,
                        );
                      },
                      getDrawingVerticalLine: (value) {
                        if (value % 2 == 0) {
                          return FlLine(
                            color: Colors.grey.withOpacity(0.1),
                            strokeWidth: 0.5,
                          );
                        }
                        return const FlLine(
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
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: _historyData.length > 0
                        ? (_historyData.length - 1).toDouble()
                        : 0,
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
                          getDotPainter:
                              (spot, percent, barData, index) {
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
                        maxContentWidth:
                            MediaQuery.of(context).size.width * 0.7,
                        getTooltipItems:
                            (List<LineBarSpot> touchedSpots) {
                          return touchedSpots
                              .map((spot) {
                            final index = spot.spotIndex;
                            if (index < 0 ||
                                index >= _historyData.length) {
                              return null;
                            }

                            final data = _historyData[index];
                            final hour = data.timestamp.hour;
                            final minute = data.timestamp.minute;
                            final time =
                                '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

                            final values = {
                              'AQI': '${data.aqi}',
                              'PM2.5':
                                  '${data.pm25.toStringAsFixed(1)} μg/m³',
                              'PM10':
                                  '${data.pm10.toStringAsFixed(1)} μg/m³',
                              'CO': '${data.co.round()} μg/m³',
                              if (data.so2 != null)
                                'SO2':
                                    '${data.so2!.toStringAsFixed(1)} μg/m³',
                              if (data.o3 != null)
                                'O3':
                                    '${data.o3!.toStringAsFixed(1)} μg/m³',
                              if (data.no2 != null)
                                'NO2':
                                    '${data.no2!.toStringAsFixed(1)} μg/m³',
                              'Suhu':
                                  '${data.temperature.toStringAsFixed(1)}°C',
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
                          })
                              .where((element) => element != null)
                              .cast<LineTooltipItem>()
                              .toList();
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

  // FIXED: tetap pertahankan padding 10% di atas & di bawah agar
  // spike (lonjakan mendadak) tetap MUAT di dalam FOV chart.
  // Contoh: data normal AQI 40-60, spike 350 → maxY = 350 × 1.1 = 385,
  // sehingga spike terlihat penuh tanpa terpotong.
  //
  // Untuk parameter opsional (SO2/O3/NO2), nilai null dilewati.
  double _getMinY() {
    if (_historyData.isEmpty) return 0.0;

    double minValue = double.infinity;
    for (var data in _historyData) {
      final value = _valueFor(data, _selectedParameter);
      if (value == null) continue;
      if (value < minValue) minValue = value;
    }

    if (minValue == double.infinity) return 0.0;
    return minValue - (minValue * 0.1);
  }

  double _getMaxY() {
    if (_historyData.isEmpty) return 100.0;

    double maxValue = double.negativeInfinity;
    for (var data in _historyData) {
      final value = _valueFor(data, _selectedParameter);
      if (value == null) continue;
      if (value > maxValue) maxValue = value;
    }

    if (maxValue == double.negativeInfinity) return 100.0;
    return maxValue + (maxValue * 0.1);
  }

  Widget _buildParameterSelector() {
    final available = _availableParameters;

    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: available.length,
        itemBuilder: (context, index) {
          final parameter = available[index];
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          Row(
            children: [
              IconButton(
                onPressed: () => _selectDate(context),
                icon: const Icon(Icons.calendar_today),
                tooltip: 'Pilih tanggal lain',
              ),
              IconButton(
                onPressed: _isLoading ? null : _loadHistoryData,
                icon: const Icon(Icons.refresh),
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
        if (_isLoading)
          Container(
            height: 350,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          )
        else if (_error.isNotEmpty && _historyData.isEmpty)
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