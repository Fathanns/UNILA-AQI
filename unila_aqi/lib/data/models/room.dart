class Room {
  final String id;
  final String name;
  final String buildingId;
  final String buildingName;
  final String dataSource;
  final String? iotDeviceId;
  final int? currentAQI;   // ✅ nullable — null = no_data
  final RoomData currentData;
  final DateTime createdAt;
  final DateTime updatedAt;

  Room({
    required this.id,
    required this.name,
    required this.buildingId,
    required this.buildingName,
    required this.dataSource,
    this.iotDeviceId,
    this.currentAQI,
    required this.currentData,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      buildingId: json['building'] is String
          ? json['building']
          : json['building']['_id'] ?? json['building']['id'],
      buildingName: json['buildingName'] ??
          (json['building'] is Map ? json['building']['name'] : 'Unknown'),
      dataSource: json['dataSource'] ?? 'simulation',
      iotDeviceId: json['iotDeviceId'],
      currentAQI: json['currentAQI'] == null
          ? null
          : (json['currentAQI'] as num).toInt(),
      currentData: RoomData.fromJson(json['currentData'] ?? {}),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'building': buildingId,
      'buildingName': buildingName,
      'dataSource': dataSource,
      'iotDeviceId': iotDeviceId,
      'currentAQI': currentAQI,
      'currentData': currentData.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  String get displayName => '$name - $buildingName';
  bool get isSimulation => dataSource == 'simulation';
  bool get isIot => dataSource == 'iot';
  bool get hasAnyData =>
      currentData.hasPM25 ||
      currentData.hasPM10 ||
      currentData.hasCO ||
      currentData.hasSO2 ||
      currentData.hasO3 ||
      currentData.hasNO2 ||
      currentData.hasTemperature ||
      currentData.hasHumidity;
}

class RoomData {
  final double? pm25;
  final double? pm10;
  final double? co;
  final double? so2;
  final double? o3;
  final double? no2;
  final double? temperature;
  final double? humidity;
  final DateTime updatedAt;

  RoomData({
    this.pm25,
    this.pm10,
    this.co,
    this.so2,
    this.o3,
    this.no2,
    this.temperature,
    this.humidity,
    required this.updatedAt,
  });

  static double? _n(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final parsed = double.tryParse(v.toString());
    return parsed;
  }

  factory RoomData.fromJson(Map<String, dynamic> json) {
    return RoomData(
      pm25: _n(json['pm25']),
      pm10: _n(json['pm10']),
      co: _n(json['co']),
      so2: _n(json['so2']),
      o3: _n(json['o3']),
      no2: _n(json['no2']),
      temperature: _n(json['temperature']),
      humidity: _n(json['humidity']),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pm25': pm25,
      'pm10': pm10,
      'co': co,
      'so2': so2,
      'o3': o3,
      'no2': no2,
      'temperature': temperature,
      'humidity': humidity,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  bool get hasPM25        => pm25 != null;
  bool get hasPM10        => pm10 != null;
  bool get hasCO          => co != null;
  bool get hasSO2         => so2 != null;
  bool get hasO3          => o3 != null;
  bool get hasNO2         => no2 != null;
  bool get hasTemperature => temperature != null;
  bool get hasHumidity    => humidity != null;
}