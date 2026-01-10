// historical_data.dart
import 'package:unila_aqi/core/utils/date_formatter.dart';

class HistoricalData {
  final DateTime timestamp;
  final double aqi;
  final double pm25;
  final double pm10;
  final double temperature;
  final double humidity;
  final double co2;
  final int? hour;
  final int? minute;
  final String? dayName;
  final String? formattedDate;
  final String? displayDate;
  final double? maxAqi;
  final double? minAqi;

  HistoricalData({
    required this.timestamp,
    required this.aqi,
    this.pm25 = 0,
    this.pm10 = 0,
    this.temperature = 0,
    this.humidity = 0,
    this.co2 = 0,
    this.hour,
    this.minute,
    this.dayName,
    this.formattedDate,
    this.displayDate,
    this.maxAqi,
    this.minAqi,
  });

  factory HistoricalData.fromJson(Map<String, dynamic> json) {
    return HistoricalData(
      timestamp: DateTime.parse(json['timestamp']).toLocal(),
      aqi: (json['aqi'] ?? json['avgAqi'] ?? 0).toDouble(),
      pm25: (json['pm25'] ?? json['avgPm25'] ?? 0).toDouble(),
      pm10: (json['pm10'] ?? json['avgPm10'] ?? 0).toDouble(),
      temperature: (json['temperature'] ?? 0).toDouble(),
      humidity: (json['humidity'] ?? 0).toDouble(),
      co2: (json['co2'] ?? 0).toDouble(),
      hour: json['hour'],
      minute: json['minute'],
      dayName: json['dayName'],
      formattedDate: json['formattedDate'],
      displayDate: json['displayDate'],
      maxAqi: (json['maxAqi'] ?? 0).toDouble(),
      minAqi: (json['minAqi'] ?? 0).toDouble(),
    );
  }

  String getFormattedTime() {
    if (hour != null && minute != null) {
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }
    return DateFormatter.formatTime(timestamp);
  }

  String getTooltipText() {
    if (displayDate != null) {
      return 'AQI: ${aqi.toStringAsFixed(1)}\n$displayDate';
    }
    return 'AQI: ${aqi.toStringAsFixed(1)}\n${getFormattedTime()}';
  }
}