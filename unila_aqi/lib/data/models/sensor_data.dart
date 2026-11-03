class SensorData {
  final String id;
  final String roomId;
  final String roomName;
  final String buildingName;
  final int aqi;
  final double pm25;
  final double pm10;
  final double co;
  final double? so2;
  final double? o3;
  final double? no2;
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
    required this.co,
     this.so2,
     this.o3,
     this.no2,
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
      co: (json['co'] ?? 0).toDouble(),
      so2: _nullableDouble(json['so2']),
      o3: _nullableDouble(json['o3']),
      no2: _nullableDouble(json['no2']),
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

  static double? _nullableDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
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
      'co': co,
      'so2': so2,
      'o3': o3,
      'no2': no2,
      'temperature': temperature,
      'humidity': humidity,
      'category': category,
      'timestamp': timestamp.toIso8601String(),
      'rawData': rawData,
      'timeLabel': timeLabel,
    };
  }
}