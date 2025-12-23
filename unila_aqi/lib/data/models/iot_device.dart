import 'package:flutter/material.dart';

class IoTDevice {
  final String id;
  final String name;
  final String? description;
  final String? buildingId;
  final String? buildingName;
  final String apiEndpoint;
  final bool isActive;
  final DateTime? lastUpdate;
  final String status; // 'online', 'offline', 'error'
  final DateTime createdAt;
  final DateTime updatedAt;

  IoTDevice({
    required this.id,
    required this.name,
    this.description,
    this.buildingId,
    this.buildingName,
    required this.apiEndpoint,
    required this.isActive,
    this.lastUpdate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory IoTDevice.fromJson(Map<String, dynamic> json) {
    return IoTDevice(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      description: json['description'],
      buildingId: json['building'] is String
          ? json['building']
          : json['building']?['_id'],
      buildingName: json['buildingName'] ??
          (json['building'] is Map ? json['building']['name'] : null),
      apiEndpoint: json['apiEndpoint'],
      isActive: json['isActive'] ?? true,
      lastUpdate: json['lastUpdate'] != null
          ? DateTime.parse(json['lastUpdate'])
          : null,
      status: json['status'] ?? 'offline',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'building': buildingId,
      'buildingName': buildingName,
      'apiEndpoint': apiEndpoint,
      'isActive': isActive,
      'lastUpdate': lastUpdate?.toIso8601String(),
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  String get displayStatus {
    switch (status) {
      case 'online':
        return 'Online';
      case 'offline':
        return 'Offline';
      case 'error':
        return 'Error';
      default:
        return 'Unknown';
    }
  }

  Color get statusColor {
    switch (status) {
      case 'online':
        return Colors.green;
      case 'offline':
        return Colors.grey;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  bool get isOnline => status == 'online';
}