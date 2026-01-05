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
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      id: json['_id'] ?? json['id'],
      roomId: json['roomId'],
      roomName: json['roomName'],
      buildingName: json['buildingName'],
      aqi: json['aqi'],
      pm25: (json['pm25'] ?? 0).toDouble(),
      pm10: (json['pm10'] ?? 0).toDouble(),
      co2: (json['co2'] ?? 0).toDouble(),
      temperature: (json['temperature'] ?? 0).toDouble(),
      humidity: (json['humidity'] ?? 0).toDouble(),
      category: json['category'],
      timestamp: DateTime.parse(json['timestamp']),
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
    };
  }
}

