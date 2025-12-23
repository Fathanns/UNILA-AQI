class Building {
  final String id;
  final String name;
  final String? code;
  final String? description;
  final int roomCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Building({
    required this.id,
    required this.name,
    this.code,
    this.description,
    required this.roomCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Building.fromJson(Map<String, dynamic> json) {
    return Building(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      code: json['code'],
      description: json['description'],
      roomCount: json['roomCount'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'description': description,
      'roomCount': roomCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  String get displayName {
    return code != null ? '$name ($code)' : name;
  }
}