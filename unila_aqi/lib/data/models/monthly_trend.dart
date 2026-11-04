class MonthlyTrendResponse {
  final int year;
  final int month;
  final List<MonthlyDayData> days;

  MonthlyTrendResponse({
    required this.year,
    required this.month,
    required this.days,
  });

  factory MonthlyTrendResponse.fromJson(Map<String, dynamic> json) {
    final daysRaw = json['days'] as List? ?? const [];
    return MonthlyTrendResponse(
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      month: (json['month'] as num?)?.toInt() ?? DateTime.now().month,
      days: daysRaw
          .whereType<Map>()
          .map((e) => MonthlyDayData.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  bool get hasAnyData => days.any((d) => d.hasData);
}

class MonthlyDayData {
  final int day;          // 1=Senin .. 7=Minggu
  final String dayName;
  final bool hasData;
  final int weekCount;
  final Map<String, ParamStats> values;

  MonthlyDayData({
    required this.day,
    required this.dayName,
    required this.hasData,
    required this.weekCount,
    required this.values,
  });

  factory MonthlyDayData.fromJson(Map<String, dynamic> json) {
    final rawValues = json['values'];
    final map = <String, ParamStats>{};
    if (rawValues is Map) {
      rawValues.forEach((k, v) {
        if (v is Map) {
          map[k.toString()] =
              ParamStats.fromJson(Map<String, dynamic>.from(v));
        }
      });
    }
    return MonthlyDayData(
      day: (json['day'] as num?)?.toInt() ?? 0,
      dayName: json['dayName']?.toString() ?? '',
      hasData: json['hasData'] == true,
      weekCount: (json['weekCount'] as num?)?.toInt() ?? 0,
      values: map,
    );
  }
}

class ParamStats {
  final double? max;
  final double? avg;
  final double? min;

  ParamStats({this.max, this.avg, this.min});

  factory ParamStats.fromJson(Map<String, dynamic> json) {
    double? n(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }
    return ParamStats(
      max: n(json['max']),
      avg: n(json['avg']),
      min: n(json['min']),
    );
  }

  double? byMetric(String metric) {
    switch (metric) {
      case 'max': return max;
      case 'avg': return avg;
      case 'min': return min;
      default: return null;
    }
  }
}