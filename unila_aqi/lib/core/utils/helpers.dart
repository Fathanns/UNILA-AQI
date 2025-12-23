import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/colors.dart';
import '../constants/app_constants.dart';

class Helpers {
  // AQI Helpers
  static Color getAQIColor(int aqi) {
    if (aqi <= 50) return AppColors.aqiGood;
    if (aqi <= 100) return AppColors.aqiModerate;
    if (aqi <= 150) return AppColors.aqiUnhealthySensitive;
    if (aqi <= 200) return AppColors.aqiUnhealthy;
    if (aqi <= 300) return AppColors.aqiVeryUnhealthy;
    return AppColors.aqiHazardous;
  }

  static String getAQILabel(int aqi) {
    if (aqi <= 50) return 'BAIK';
    if (aqi <= 100) return 'SEDANG';
    if (aqi <= 150) return 'TIDAK SEHAT';
    if (aqi <= 200) return 'SANGAT TIDAK SEHAT';
    if (aqi <= 300) return 'BERBAHAYA';
    return 'BERBAHAYA';
  }

  static String getAQIHealthMessage(int aqi) {
    if (aqi <= 50) return AppConstants.healthRecommendations['good']!;
    if (aqi <= 100) return AppConstants.healthRecommendations['moderate']!;
    if (aqi <= 150) return AppConstants.healthRecommendations['unhealthy']!;
    if (aqi <= 200) return AppConstants.healthRecommendations['very_unhealthy']!;
    if (aqi <= 300) return AppConstants.healthRecommendations['hazardous']!;
    return AppConstants.healthRecommendations['dangerous']!;
  }

  // Parameter Status Helpers
  static String getPM25Status(double value) {
    if (value <= 12) return 'BAIK';
    if (value <= 35.4) return 'SEDANG';
    if (value <= 55.4) return 'TIDAK SEHAT';
    if (value <= 150.4) return 'SANGAT TIDAK SEHAT';
    if (value <= 250.4) return 'BERBAHAYA';
    return 'BERBAHAYA';
  }

  static Color getPM25Color(double value) {
    if (value <= 12) return AppColors.aqiGood;
    if (value <= 35.4) return AppColors.aqiModerate;
    if (value <= 55.4) return AppColors.aqiUnhealthySensitive;
    if (value <= 150.4) return AppColors.aqiUnhealthy;
    if (value <= 250.4) return AppColors.aqiVeryUnhealthy;
    return AppColors.aqiHazardous;
  }

  static String getTemperatureStatus(double value) {
    if (value >= 22 && value <= 26) return 'IDEAL';
    if (value >= 20 && value <= 28) return 'NORMAL';
    if (value >= 18 && value <= 30) return 'SEDANG';
    return 'TIDAK IDEAL';
  }

  static Color getTemperatureColor(double value) {
    if (value >= 22 && value <= 26) return AppColors.success;
    if (value >= 20 && value <= 28) return AppColors.aqiGood;
    if (value >= 18 && value <= 30) return AppColors.aqiModerate;
    return AppColors.aqiUnhealthySensitive;
  }

  static String getHumidityStatus(double value) {
    if (value >= 40 && value <= 60) return 'IDEAL';
    if (value >= 30 && value <= 70) return 'NORMAL';
    if (value >= 20 && value <= 80) return 'SEDANG';
    return 'TIDAK IDEAL';
  }

  static Color getHumidityColor(double value) {
    if (value >= 40 && value <= 60) return AppColors.success;
    if (value >= 30 && value <= 70) return AppColors.aqiGood;
    if (value >= 20 && value <= 80) return AppColors.aqiModerate;
    return AppColors.aqiUnhealthySensitive;
  }

  static String getCO2Status(double value) {
    if (value <= 600) return 'BAIK';
    if (value <= 1000) return 'SEDANG';
    if (value <= 1500) return 'TIDAK SEHAT';
    if (value <= 2000) return 'SANGAT TIDAK SEHAT';
    return 'BERBAHAYA';
  }

  static Color getCO2Color(double value) {
    if (value <= 600) return AppColors.aqiGood;
    if (value <= 1000) return AppColors.aqiModerate;
    if (value <= 1500) return AppColors.aqiUnhealthySensitive;
    if (value <= 2000) return AppColors.aqiUnhealthy;
    return AppColors.aqiVeryUnhealthy;
  }

  // Date & Time Helpers
  static String formatDateTime(DateTime dateTime, {String format = 'dd/MM/yyyy HH:mm'}) {
    return DateFormat(format).format(dateTime);
  }

  static String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds} detik lalu';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari lalu';
    } else {
      return DateFormat('dd MMM yyyy').format(dateTime);
    }
  }

  // UI Helpers
  static void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  static void showLoadingDialog(BuildContext context, {String message = 'Memuat...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  static void dismissLoadingDialog(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  // Validation Helpers
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  static bool isValidPassword(String password) {
    return password.length >= 8;
  }

  // String Helpers
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  static String truncateWithEllipsis(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  // JSON Helpers
  static Map<String, dynamic> safeJsonDecode(String jsonString) {
    try {
      return jsonDecode(jsonString);
    } catch (e) {
      return {};
    }
  }

  static String safeJsonEncode(Map<String, dynamic> data) {
    try {
      return jsonEncode(data);
    } catch (e) {
      return '{}';
    }
  }

  // Network Helpers
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  // Color Helpers
  static Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  static String colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }
}