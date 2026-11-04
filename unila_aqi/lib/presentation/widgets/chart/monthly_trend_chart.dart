import 'package:flutter/material.dart';
import 'package:unila_aqi/core/constants/colors.dart';
import 'package:unila_aqi/core/constants/parameter_colors.dart';
import 'package:unila_aqi/core/services/api_service.dart';
import 'package:unila_aqi/core/utils/helpers.dart';
import 'package:unila_aqi/data/models/monthly_trend.dart';

class MonthlyTrendChart extends StatefulWidget {
  final String roomId;

  const MonthlyTrendChart({super.key, required this.roomId});

  @override
  State<MonthlyTrendChart> createState() => _MonthlyTrendChartState();
}

class _MonthlyTrendChartState extends State<MonthlyTrendChart> {
  late int _year;
  late int _month;
  String _parameter = 'aqi';

  bool _isLoading = false;
  String _error = '';
  MonthlyTrendResponse? _response;

  static const Map<String, String> _paramLabels = {
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

  static const Map<String, String> _paramUnits = {
    'aqi': '',
    'pm25': 'μg/m³',
    'pm10': 'μg/m³',
    'co': 'μg/m³',
    'so2': 'μg/m³',
    'o3': 'μg/m³',
    'no2': 'μg/m³',
    'temperature': '°C',
    'humidity': '%',
  };

  static const List<String> _paramOrder = [
    'aqi', 'pm25', 'pm10', 'co', 'so2', 'o3', 'no2',
    'temperature', 'humidity',
  ];

  static const List<String> _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final hadData = _response != null && _response!.hasAnyData;

    setState(() {
      _isLoading = !hadData;
      _error = '';
    });

    final result = await ApiService()
        .getMonthlyTrend(widget.roomId, year: _year, month: _month);

    if (!mounted) return;

    if (result is Map && result['success'] == true) {
      setState(() {
        _response = MonthlyTrendResponse.fromJson(
          Map<String, dynamic>.from(result),
        );
        _isLoading = false;
      });
    } else {
      final errStr = (result is Map) ? result['error']?.toString() ?? '' : '';
      setState(() {
        _isLoading = false;
        _error = Helpers.isNetworkError(errStr)
            ? 'Tidak dapat memuat trend bulanan karena server tidak dapat dihubungi.'
            : 'Gagal memuat trend bulanan.';
      });
      if (Helpers.isNetworkError(errStr)) {
        Helpers.showServerError(context);
      } else {
        Helpers.showSnackBar(context, 'Gagal memuat trend bulanan',
            isError: true);
      }
    }
  }

  Future<void> _changeMonth(int delta) async {
    final now = DateTime.now();
    int newMonth = _month + delta;
    int newYear = _year;

    if (newMonth < 1) {
      newMonth = 12;
      newYear -= 1;
    } else if (newMonth > 12) {
      newMonth = 1;
      newYear += 1;
    }

    final candidate = DateTime(newYear, newMonth);
    final current = DateTime(now.year, now.month);
    if (candidate.isAfter(current)) return;

    setState(() {
      _year = newYear;
      _month = newMonth;
    });
    await _loadData();
  }

  Future<void> _pickMonthYear() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MonthYearPickerSheet(
        initialYear: _year,
        initialMonth: _month,
      ),
    );

    if (picked != null) {
      setState(() {
        _year = picked.year;
        _month = picked.month;
      });
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
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
              const Icon(Icons.bar_chart_rounded,
                  color: Colors.blue, size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'TREND HARIAN BULANAN',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: _isLoading ? null : _loadData,
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh trend bulanan',
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildMonthYearSelector(),
          const SizedBox(height: 10),
          _buildParameterChips(),
          const SizedBox(height: 12),
          if (_isLoading)
            const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error.isNotEmpty)
            _buildErrorState()
          else if (_response == null || !_response!.hasAnyData)
            _buildEmptyState()
          else
            ..._buildAllCharts(),
        ],
      ),
    );
  }

  Widget _buildMonthYearSelector() {
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
            onPressed: () => _changeMonth(-1),
            tooltip: 'Bulan sebelumnya',
          ),
          Expanded(
            child: InkWell(
              onTap: _pickMonthYear,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text(
                      '${_monthNames[_month - 1]} $_year',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeMonth(1),
            tooltip: 'Bulan berikutnya',
          ),
        ],
      ),
    );
  }

  Widget _buildParameterChips() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _paramOrder.length,
        itemBuilder: (context, index) {
          final p = _paramOrder[index];
          final isSelected = _parameter == p;
          final color = ParameterColors.of(p);

          return GestureDetector(
            onTap: () => setState(() => _parameter = p),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                // ✅ Selected = warna parameter itu sendiri
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
                      _paramLabels[p] ?? p,
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

  List<Widget> _buildAllCharts() {
    final resp = _response!;
    final unit = _paramUnits[_parameter] ?? '';
    final label = _paramLabels[_parameter] ?? _parameter;

    final baseColor = ParameterColors.of(_parameter);

    return [
      _MonthlyBarChart(
        title: 'Tertinggi',
        subtitle: 'Nilai $label tertinggi dalam bulan ini',
        days: resp.days,
        parameter: _parameter,
        metric: 'max',
        unit: unit,
        color: baseColor,
      ),
      const SizedBox(height: 12),
      _MonthlyBarChart(
        title: 'Rata-rata',
        subtitle: 'Rata-rata nilai $label harian dalam bulan ini',
        days: resp.days,
        parameter: _parameter,
        metric: 'avg',
        unit: unit,
        color: baseColor,
      ),
      const SizedBox(height: 12),
      _MonthlyBarChart(
        title: 'Terendah',
        subtitle: 'Nilai $label terendah dari semua hari sejenis dalam bulan ini',
        days: resp.days,
        parameter: _parameter,
        metric: 'min',
        unit: unit,
        color: baseColor,
      ),
    ];
  }

  Widget _buildErrorState() {
    return SizedBox(
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(
            _error,
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart_outlined,
                size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(
              'Tidak ada data di ${_monthNames[_month - 1]} $_year',
              style: const TextStyle(color: AppColors.textHint),
            ),
            const SizedBox(height: 4),
            const Text(
              '(atau semua data adalah anomali/error)',
              style: TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// BAR CHART PER METRIK
// ============================================================
class _MonthlyBarChart extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<MonthlyDayData> days;
  final String parameter;
  final String metric;
  final String unit;
  final Color color;

  const _MonthlyBarChart({
    required this.title,
    required this.subtitle,
    required this.days,
    required this.parameter,
    required this.metric,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final values = days
        .map((d) => d.values[parameter]?.byMetric(metric))
        .toList(growable: false);

    final maxVal = values
        .whereType<double>()
        .fold<double>(0.0, (a, b) => b > a ? b : a);
    final chartMax = maxVal > 0 ? maxVal * 1.15 : 1.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFamily: 'Inter',
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  '($unit)',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textHint,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 140,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final labelSpace = 30.0;
                final barAreaHeight = constraints.maxHeight - labelSpace;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(days.length, (i) {
                    final day = days[i];
                    final value = values[i];
                    final hasData = value != null;

                    final barHeight = hasData
                        ? (value / chartMax) * barAreaHeight
                        : 0.0;

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              height: 14,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  hasData
                                      ? _formatValue(value, parameter)
                                      : '—',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: hasData
                                        ? AppColors.textPrimary
                                        : AppColors.textHint,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              height: hasData && barHeight > 4
                                  ? barHeight
                                  : 4,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: hasData
                                    ? color
                                    : Colors.grey.withOpacity(0.3),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 12,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _dayShort(day.dayName),
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _formatValue(double v, String parameter) {
    if (parameter == 'aqi') return v.round().toString();
    if (parameter == 'humidity') return v.round().toString();
    if (parameter == 'co') return v.round().toString();
    return v.toStringAsFixed(1);
  }

  static String _dayShort(String dayName) {
    const map = {
      'Senin': 'Sen',
      'Selasa': 'Sel',
      'Rabu': 'Rab',
      'Kamis': 'Kam',
      'Jumat': 'Jum',
      'Sabtu': 'Sab',
      'Minggu': 'Min',
    };
    return map[dayName] ?? dayName;
  }
}

// ============================================================
// MONTH/YEAR PICKER BOTTOM SHEET
// ============================================================
class _MonthYearPickerSheet extends StatefulWidget {
  final int initialYear;
  final int initialMonth;

  const _MonthYearPickerSheet({
    required this.initialYear,
    required this.initialMonth,
  });

  @override
  State<_MonthYearPickerSheet> createState() => _MonthYearPickerSheetState();
}

class _MonthYearPickerSheetState extends State<_MonthYearPickerSheet> {
  late int _year;
  late int _month;

  static const List<String> _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _month = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final minYear = now.year - 5;
    final maxYear = now.year;
    final years = List.generate(maxYear - minYear + 1, (i) => minYear + i);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pilih Bulan & Tahun',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              DropdownButton<int>(
                value: _year,
                isExpanded: true,
                onChanged: (v) => setState(() => _year = v ?? _year),
                items: years
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                    .toList(),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: List.generate(12, (i) {
                  final m = i + 1;
                  final isSelected = m == _month;
                  final isFuture = (_year == now.year && m > now.month);

                  return GestureDetector(
                    onTap: isFuture
                        ? null
                        : () {
                            setState(() => _month = m);
                          },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : (isFuture
                                ? Colors.grey.withOpacity(0.08)
                                : AppColors.surface),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        _monthNames[i],
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isFuture
                                  ? AppColors.textDisabled
                                  : AppColors.textPrimary),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(
                        context,
                        DateTime(_year, _month),
                      ),
                      child: const Text('Terapkan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}