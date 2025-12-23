class Room {
  final String id;
  final String name;
  final String buildingId;
  final String buildingName;
  final String dataSource; // 'simulation' or 'iot'
  final String? iotDeviceId;
  final bool isActive;
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
    required this.isActive,
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
      isActive: json['isActive'] ?? true,
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
      'isActive': isActive,
      'currentAQI': currentAQI,
      'currentData': currentData.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  String get displayName {
    return '$name - $buildingName';
  }

  bool get isSimulation => dataSource == 'simulation';
  bool get isIot => dataSource == 'iot';
}

class RoomData {
  final double pm25;
  final double pm10;
  final double co2;
  final double temperature;
  final double humidity;
  final DateTime updatedAt;

  RoomData({
    required this.pm25,
    required this.pm10,
    required this.co2,
    required this.temperature,
    required this.humidity,
    required this.updatedAt,
  });

  factory RoomData.fromJson(Map<String, dynamic> json) {
    return RoomData(
      pm25: (json['pm25'] ?? 0).toDouble(),
      pm10: (json['pm10'] ?? 0).toDouble(),
      co2: (json['co2'] ?? 0).toDouble(),
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
      'co2': co2,
      'temperature': temperature,
      'humidity': humidity,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}