import 'dart:ui';

class AQIInfo {
  final String title;
  final String description;
  final String icon;
  final List<AQIParameter> parameters;
  final List<AQICategory> categories;
  final List<UnitInfo> units;

  AQIInfo({
    required this.title,
    required this.description,
    required this.icon,
    required this.parameters,
    required this.categories,
    required this.units,
  });
}

class AQIParameter {
  final String name;
  final String abbreviation;
  final String description;
  final String unit;
  final String impact;
  final String source;
  final String safeRange;
  final String icon;

  AQIParameter({
    required this.name,
    required this.abbreviation,
    required this.description,
    required this.unit,
    required this.impact,
    required this.source,
    required this.safeRange,
    required this.icon,
  });
}

class AQICategory {
  final String name;
  final String description;
  final Color color;
  final int min;
  final int max;
  final String healthEffect;
  final String recommendation;

  AQICategory({
    required this.name,
    required this.description,
    required this.color,
    required this.min,
    required this.max,
    required this.healthEffect,
    required this.recommendation,
  });
}

class UnitInfo {
  final String symbol;
  final String name;
  final String description;
  final String example;

  UnitInfo({
    required this.symbol,
    required this.name,
    required this.description,
    required this.example,
  });
}