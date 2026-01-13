import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF0066CC);
  static const Color primaryDark = Color(0xFF0052A3);
  static const Color primaryLight = Color(0xFF3388FF);
  
  // Secondary Colors
  static const Color secondary = Color(0xFF00B894);
  static const Color secondaryDark = Color(0xFF00A085);
  static const Color secondaryLight = Color(0xFF55EFC4);
  
  // AQI Colors (from US EPA standard)
  static const Color aqiGood = Color(0xFF00E400); // Green
  static const Color aqiModerate = Color(0xFFFFFF00); // Yellow
  static const Color aqiUnhealthySensitive = Color(0xFFFF7E00); // Orange
  static const Color aqiUnhealthy = Color(0xFFFF0000); // Red
  static const Color aqiVeryUnhealthy = Color(0xFF8F3F97); // Purple
  static const Color aqiHazardous = Color(0xFF7E0023); // Maroon
  
  // Neutral Colors
  static const Color background = Color(0xFFF8F9FA);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF1F3F5);
  static const Color border = Color(0xFFDEE2E6);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF212529);
  static const Color textSecondary = Color(0xFF495057);
  static const Color textHint = Color(0xFF6C757D);
  static const Color textDisabled = Color(0xFFADB5BD);
  
  // Status Colors
  static const Color success = Color(0xFF28A745);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFDC3545);
  static const Color info = Color(0xFF17A2B8);

  
  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}