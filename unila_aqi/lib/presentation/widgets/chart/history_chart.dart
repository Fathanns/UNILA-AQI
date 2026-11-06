import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:unila_aqi/core/constants/colors.dart';
import 'package:unila_aqi/core/constants/parameter_colors.dart';
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
  State<HistoryChart> createState() => HistoryChartState();
}

class HistoryChartState extends State<HistoryChart> {
  List<SensorData> _historyData = [];
  DateTime _selectedDate = DateTime.now();
  String _selectedParameter = 'aqi';
  bool _isLoading = false;
  String _error = '';
  final ScrollController _scrollController = ScrollController();

  static const int _pointsInView = 8;
  static const double _containerPadding = 16.0;

  static const List<String> _allParameters = [
    'aqi', 'pm25', 'pm10', 'co', 'so2', 'o3', 'no2', 'temperature', 'humidity',
  ];

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

  static const List<String> _dayNames = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
  ];
  static const List<String> _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  String _formatSelectedDate(DateTime d) {
    final dayName = _dayNames[d.weekday - 1];
    final monthName = _monthNames[d.month - 1];
    return '$dayName, ${d.day} $monthName ${d.year}';
  }

  Future<void> refresh() async {
    await _loadHistoryData();
  }

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

  double? _valueFor(SensorData data, String parameter) {
    switch (parameter) {
      case 'aqi':         return data.aqi?.toDouble();
      case 'pm25':        return data.pm25;
      case 'pm10':        return data.pm10;
      case 'co':          return data.co;
      case 'so2':         return data.so2;
      case 'o3':          return data.o3;
      case 'no2':         return data.no2;
      case 'temperature': return data.temperature;
      case 'humidity':    return data.humidity;
      default:            return null;
    }
  }

  List<String> get _availableParameters {
    return _allParameters.where((p) {
      return _historyData.any((d) => _valueFor(d, p) != null);
    }).toList();
  }

  Future<void> _loadHistoryData() async {
    if (!mounted) return;

    final hadData = _historyData.isNotEmpty;

    setState(() {
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
            .map((json) => SensorData.fromJson(Map<String, dynamic>.from(json)))
            .toList();

        setState(() {
          _historyData = parsed;
          if (!_availableParameters.contains(_selectedParameter)) {
            _selectedParameter =
                _availableParameters.isNotEmpty ? _availableParameters.first : 'aqi';
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
        Helpers.showSnackBar(context, 'Gagal memuat data grafik', isError: true);
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _selectDate(BuildContext context) async {
    try {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime.now().subtract(const Duration(days: 30)),
        lastDate: DateTime.now(),
      );
      if (picked != null && picked != _selectedDate) {
        setState(() => _selectedDate = picked);
        await _loadHistoryData();
      }
    } catch (e) {
      debugPrint('❌ Date picker error: $e');
      if (mounted) {
        Helpers.showSnackBar(context, 'Gagal membuka pemilih tanggal',
            isError: true);
      }
    }
  }

  Future<void> _changeDay(int delta) async {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final minDate = todayStart.subtract(const Duration(days: 30));

    final candidate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day + delta,
    );

    if (candidate.isAfter(todayStart)) return;
    if (candidate.isBefore(minDate)) return;

    setState(() => _selectedDate = candidate);
    await _loadHistoryData();
  }

  // ============================================================
  // CHART DATA POINTS
  // Semua index dimasukkan sebagai spot. Titik dengan nilai null
  // (IoT tidak kirim) ATAU negatif (error -1) ditaruh di minY
  // (= bawah chart) supaya dot tetap terlihat.
  // ============================================================
  List<FlSpot> _getDataPoints() {
    final bottomY = _getMinY();
    final spots = <FlSpot>[];
    for (int i = 0; i < _historyData.length; i++) {
      final y = _valueFor(_historyData[i], _selectedParameter);
      if (y == null || y < 0) {
        spots.add(FlSpot(i.toDouble(), bottomY));
      } else {
        spots.add(FlSpot(i.toDouble(), y));
      }
    }
    return spots;
  }

  SideTitles _getBottomTitles() {
    return SideTitles(
      showTitles: true,
      reservedSize: 30,
      interval: 1,
      getTitlesWidget: (value, meta) {
        final index = value.toInt();
        if (value != index.toDouble()) return const SizedBox.shrink();
        if (index < 0 || index >= _historyData.length) {
          return const SizedBox.shrink();
        }
        final data = _historyData[index];
        if (data.timestamp.minute != 0) return const SizedBox.shrink();

        final hourLabel = data.timestamp.hour.toString().padLeft(2, '0');
        return Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            '$hourLabel:00',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        );
      },
    );
  }

  Widget _buildChart() {
    final spots = _getDataPoints();
    final color = ParameterColors.of(_selectedParameter);

    final screenWidth = MediaQuery.of(context).size.width;
    final availableViewport = screenWidth - (_containerPadding * 2);
    final pointSpacing = availableViewport / _pointsInView;
    final calculatedWidth = _historyData.length * pointSpacing;
    final actualChartWidth = calculatedWidth > availableViewport
        ? calculatedWidth
        : availableViewport;

    return Container(
      height: 350,
      padding: const EdgeInsets.all(_containerPadding),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Grafik ${_parameterLabels[_selectedParameter]}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle),
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
                      getDrawingHorizontalLine: (value) => const FlLine(
                        color: Colors.transparent,
                        strokeWidth: 0,
                      ),
                      getDrawingVerticalLine: (value) {
                        if (value % 2 == 0) {
                          return FlLine(
                            color: Colors.grey.withOpacity(0.1),
                            strokeWidth: 0.5,
                          );
                        }
                        return const FlLine(
                            color: Colors.transparent, strokeWidth: 0);
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
                        maxContentWidth:
                            MediaQuery.of(context).size.width * 0.7,
                        getTooltipItems: (List<LineBarSpot> touchedSpots) {
                          return touchedSpots.map((spot) {
                            final index = spot.spotIndex;
                            if (index < 0 || index >= _historyData.length) {
                              return null;
                            }
                            final data = _historyData[index];
                            final time =
                                '${data.timestamp.hour.toString().padLeft(2, '0')}:${data.timestamp.minute.toString().padLeft(2, '0')}';

                            // Deteksi no-data: null (IoT) atau negatif (error -1)
                            final rawValue =
                                _valueFor(data, _selectedParameter);
                            final isNoData =
                                rawValue == null || rawValue < 0;

                            if (isNoData) {
                              return LineTooltipItem(
                                'Waktu: $time\n\nTidak ada data',
                                const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              );
                            }

                            // Breakdown: hanya field valid (non-null DAN >= 0)
                            final values = <String, String>{
                              if (data.aqi != null && data.aqi! >= 0)
                                'AQI': '${data.aqi}',
                              if (data.pm25 != null && data.pm25! >= 0)
                                'PM2.5':
                                    '${data.pm25!.toStringAsFixed(1)} μg/m³',
                              if (data.pm10 != null && data.pm10! >= 0)
                                'PM10':
                                    '${data.pm10!.toStringAsFixed(1)} μg/m³',
                              if (data.co != null && data.co! >= 0)
                                'CO': '${data.co!.round()} μg/m³',
                              if (data.so2 != null && data.so2! >= 0)
                                'SO2':
                                    '${data.so2!.toStringAsFixed(1)} μg/m³',
                              if (data.o3 != null && data.o3! >= 0)
                                'O3': '${data.o3!.toStringAsFixed(1)} μg/m³',
                              if (data.no2 != null && data.no2! >= 0)
                                'NO2':
                                    '${data.no2!.toStringAsFixed(1)} μg/m³',
                              if (data.temperature != null &&
                                  data.temperature! >= 0)
                                'Suhu':
                                    '${data.temperature!.toStringAsFixed(1)}°C',
                              if (data.humidity != null &&
                                  data.humidity! >= 0)
                                'Kelembaban': '${data.humidity!.round()}%',
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
                              .where((e) => e != null)
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

  // ============================================================
  // Skala Y: skip null DAN negatif (keduanya = no-data)
  // sehingga minY/maxY hanya mencerminkan data valid.
  // ============================================================
  double _getMinY() {
    if (_historyData.isEmpty) return 0.0;
    double minValue = double.infinity;
    for (var data in _historyData) {
      final value = _valueFor(data, _selectedParameter);
      if (value == null || value < 0) continue;
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
      if (value == null || value < 0) continue;
      if (value > maxValue) maxValue = value;
    }
    if (maxValue == double.negativeInfinity) return 100.0;
    return maxValue + (maxValue * 0.1);
  }

  Widget _buildParameterSelector() {
    final available = _availableParameters;
    if (available.isEmpty) return const SizedBox(height: 40);

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: available.length,
        itemBuilder: (context, index) {
          final parameter = available[index];
          final isSelected = _selectedParameter == parameter;
          final color = ParameterColors.of(parameter);

          return GestureDetector(
            onTap: () => setState(() => _selectedParameter = parameter),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? color
                    : AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
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
                  Center(
                    child: Text(
                      _parameterLabels[parameter]!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : color,
                        fontFamily: 'Inter',
                      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeDay(-1),
            tooltip: 'Hari sebelumnya',
          ),
          Expanded(
            child: InkWell(
              onTap: () => _selectDate(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text(
                      _formatSelectedDate(_selectedDate),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeDay(1),
            tooltip: 'Hari berikutnya',
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
        const SizedBox(height: 10),
        _buildParameterSelector(),
        const SizedBox(height: 12),
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
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
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
        else if (_historyData.isEmpty || _availableParameters.isEmpty)
          Container(
            height: 350,
            alignment: Alignment.center,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bar_chart_outlined,
                    size: 48, color: AppColors.textHint),
                SizedBox(height: 12),
                Text(
                  'Tidak ada data history untuk tanggal ini',
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontFamily: 'Inter',
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