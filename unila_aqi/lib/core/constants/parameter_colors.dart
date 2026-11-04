import 'package:flutter/material.dart';
import 'colors.dart';

class ParameterColors {
  ParameterColors._();

  static const Map<String, Color> colors = {
    'aqi':  AppColors.primary,               // biru
    'pm25': AppColors.aqiUnhealthy,          // merah
    'pm10': AppColors.aqiUnhealthySensitive, // kuning
    'o3':   AppColors.aqiGood,               // hijau
    'co':          Color(0xFF607D8B), // Blue Grey 500
    'so2':         Color(0xFF795548), // Brown 500
    'no2':         Color(0xFF9C27B0), // Purple 500
    'temperature': Color(0xFFFF9800), // Orange 500
    'humidity':    Color(0xFF00BCD4), // Cyan 500
  };

  static Color of(String parameter) =>
      colors[parameter] ?? AppColors.textHint;
}