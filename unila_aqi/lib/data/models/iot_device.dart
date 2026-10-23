import 'package:flutter/material.dart';

class IoTDevice {
  final String id;
  final String name;
  final String? description;
  final String apiEndpoint;
  final DateTime? lastUpdate;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  IoTDevice({
    required this.id,
    required this.name,
    this.description,
    required this.apiEndpoint,
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
      apiEndpoint: json['apiEndpoint'],
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
      'apiEndpoint': apiEndpoint,
      'lastUpdate': lastUpdate?.toIso8601String(),
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  String get displayStatus {
    return status == 'online' ? 'Online' : 'Offline';
  }

  Color get statusColor {
    return status == 'online' ? Colors.green : Colors.grey;
  }

  bool get isOnline => status == 'online';
}