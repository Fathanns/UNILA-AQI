class Room {
  final String id;
  final String name;
  final String buildingId;
  final String buildingName;
  final String dataSource;
  final String? iotDeviceId;
  final int currentAQI;
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
    required this.currentAQI,
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
      currentAQI: json['currentAQI'] ?? 0,
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
}

class RoomData {
  final double pm25;
  final double pm10;
  final double co;
  final double? so2;
  final double? o3;
  final double? no2;
  final double temperature;
  final double humidity;
  final DateTime updatedAt;

  RoomData({
    required this.pm25,
    required this.pm10,
    required this.co,
    this.so2,
    this.o3,
    this.no2,
    required this.temperature,
    required this.humidity,
    required this.updatedAt,
  });

  static double? _nullableDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory RoomData.fromJson(Map<String, dynamic> json) {
    return RoomData(
      pm25: (json['pm25'] ?? 0).toDouble(),
      pm10: (json['pm10'] ?? 0).toDouble(),
      co: (json['co'] ?? 0).toDouble(),
      so2: _nullableDouble(json['so2']),
      o3: _nullableDouble(json['o3']),
      no2: _nullableDouble(json['no2']),
      temperature: (json['temperature'] ?? 0).toDouble(),
      humidity: (json['humidity'] ?? 0).toDouble(),
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

  bool get hasSO2 => so2 != null;
  bool get hasO3 => o3 != null;
  bool get hasNO2 => no2 != null;
}