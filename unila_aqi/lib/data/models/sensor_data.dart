class SensorData {
  final String id;
  final String roomId;
  final String roomName;
  final String buildingName;
  final int aqi;
  final double pm25;
  final double pm10;
  final double co2;
  final double temperature;
  final double humidity;
  final String category;
  final DateTime timestamp;
  final List<dynamic>? rawData; // Untuk data agregasi
  final String? timeLabel; // Untuk label waktu

  SensorData({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.buildingName,
    required this.aqi,
    required this.pm25,
    required this.pm10,
    required this.co2,
    required this.temperature,
    required this.humidity,
    required this.category,
    required this.timestamp,
    this.rawData,
    this.timeLabel,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      roomId: json['roomId']?.toString() ?? '',
      roomName: json['roomName']?.toString() ?? '',
      buildingName: json['buildingName']?.toString() ?? '',
      aqi: (json['aqi'] ?? 0).toInt(),
      pm25: (json['pm25'] ?? 0).toDouble(),
      pm10: (json['pm10'] ?? 0).toDouble(),
      co2: (json['co2'] ?? 0).toDouble(),
      temperature: (json['temperature'] ?? 0).toDouble(),
      humidity: (json['humidity'] ?? 0).toDouble(),
      category: json['category']?.toString() ?? 'baik',
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'].toString()).toLocal()
          : DateTime.now(),
      rawData: json['rawData'],
      timeLabel: json['timeLabel']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId,
      'roomName': roomName,
      'buildingName': buildingName,
      'aqi': aqi,
      'pm25': pm25,
      'pm10': pm10,
      'co2': co2,
      'temperature': temperature,
      'humidity': humidity,
      'category': category,
      'timestamp': timestamp.toIso8601String(),
      'rawData': rawData,
      'timeLabel': timeLabel,
    };
  }
}