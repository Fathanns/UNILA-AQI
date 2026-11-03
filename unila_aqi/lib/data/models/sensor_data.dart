class SensorData {
  final String id;
  final String roomId;
  final String roomName;
  final String buildingName;
  final int? aqi;
  final double? pm25;
  final double? pm10;
  final double? co;
  final double? so2;
  final double? o3;
  final double? no2;
  final double? temperature;
  final double? humidity;
  final String category;
  final DateTime timestamp;
  final List<dynamic>? rawData;
  final String? timeLabel;

  SensorData({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.buildingName,
    this.aqi,
    this.pm25,
    this.pm10,
    this.co,
    this.so2,
    this.o3,
    this.no2,
    this.temperature,
    this.humidity,
    required this.category,
    required this.timestamp,
    this.rawData,
    this.timeLabel,
  });

  static double? _n(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int? _i(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      id: json['_id']?.toString() ??
          json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      roomId: json['roomId']?.toString() ?? '',
      roomName: json['roomName']?.toString() ?? '',
      buildingName: json['buildingName']?.toString() ?? '',
      aqi: _i(json['aqi']),
      pm25: _n(json['pm25']),
      pm10: _n(json['pm10']),
      co: _n(json['co']),
      so2: _n(json['so2']),
      o3: _n(json['o3']),
      no2: _n(json['no2']),
      temperature: _n(json['temperature']),
      humidity: _n(json['humidity']),
      category: json['category']?.toString() ?? 'no_data',
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