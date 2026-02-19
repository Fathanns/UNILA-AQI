import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:unila_aqi/data/models/room.dart';
import '../constants/colors.dart';
import '../constants/app_constants.dart';

class Helpers {
  // AQI Helpers
  static Color getAQIColor(int aqi) {
    if (aqi <= 50) return AppColors.aqiGood; // hijau
    if (aqi <= 100) return AppColors.aqiModerate; // orange untuk sedang
    if (aqi <= 150) return AppColors.aqiUnhealthySensitive; // merah
    if (aqi <= 200) return AppColors.aqiUnhealthy; // purple
    if (aqi <= 300) return AppColors.aqiVeryUnhealthy; // hitam
    return AppColors.aqiHazardous; // hitam
  }

  static String getAQILabel(int aqi) {
    if (aqi <= 50) return 'BAIK';
    if (aqi <= 100) return 'SEDANG';
    if (aqi <= 150) return 'TIDAK SEHAT';
    if (aqi <= 200) return 'SANGAT TIDAK SEHAT';
    if (aqi <= 300) return 'BERBAHAYA';
    return 'SANGAT BERBAHAYA';
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
    if (value <= 12) return AppColors.aqiGood; // hijau
    if (value <= 35.4) return AppColors.aqiModerate; // orange untuk sedang
    if (value <= 55.4) return AppColors.aqiUnhealthySensitive; // merah
    if (value <= 150.4) return AppColors.aqiUnhealthy; // purple
    if (value <= 250.4) return AppColors.aqiVeryUnhealthy; // hitam
    return AppColors.aqiHazardous; // hitam
  }

  static String getPM10Status(double value) {
    if (value <= 50) return 'BAIK';
    if (value <= 100) return 'SEDANG';
    if (value <= 150) return 'TIDAK SEHAT';
    if (value <= 250) return 'SANGAT TIDAK SEHAT';
    if (value <= 350) return 'BERBAHAYA';
    return 'BERBAHAYA';
  }

  static Color getPM10Color(double value) {
    if (value <= 50) return AppColors.aqiGood; // hijau
    if (value <= 100) return AppColors.aqiModerate; // orange untuk sedang
    if (value <= 150) return AppColors.aqiUnhealthySensitive; // merah
    if (value <= 250) return AppColors.aqiUnhealthy; // purple
    if (value <= 350) return AppColors.aqiVeryUnhealthy; // hitam
    return AppColors.aqiHazardous; // hitam
  }
  

  static String getTemperatureStatus(double value) {
    if (value >= 22 && value <= 26) return 'IDEAL';
    if (value >= 20 && value <= 28) return 'NORMAL';
    if (value >= 18 && value <= 30) return 'SEDANG';
    return 'TIDAK IDEAL';
  }

  static Color getTemperatureColor(double value) {
    if (value >= 22 && value <= 26) return AppColors.success; // hijau
    if (value >= 20 && value <= 28) return Colors.orange; // orange
    if (value >= 18 && value <= 30) return AppColors.aqiUnhealthySensitive; // merah
    return AppColors.aqiUnhealthy; // purple
  }

  static String getHumidityStatus(double value) {
    if (value >= 40 && value <= 60) return 'IDEAL';
    if (value >= 30 && value <= 70) return 'NORMAL';
    if (value >= 20 && value <= 80) return 'SEDANG';
    return 'TIDAK IDEAL';
  }

  static Color getHumidityColor(double value) {
    if (value >= 40 && value <= 60) return AppColors.success; // hijau
    if (value >= 30 && value <= 70) return Colors.orange; // orange
    if (value >= 20 && value <= 80) return AppColors.aqiUnhealthySensitive; // merah
    return AppColors.aqiUnhealthy; // purple
  }

  static String getCO2Status(double value) {
    if (value <= 600) return 'BAIK';
    if (value <= 1000) return 'SEDANG';
    if (value <= 1500) return 'TIDAK SEHAT';
    if (value <= 2000) return 'SANGAT TIDAK SEHAT';
    return 'BERBAHAYA';
  }

  static Color getCO2Color(double value) {
    if (value <= 600) return AppColors.aqiGood; // hijau
    if (value <= 1000) return Colors.orange; // orange untuk sedang
    if (value <= 1500) return AppColors.aqiUnhealthySensitive; // merah
    if (value <= 2000) return AppColors.aqiUnhealthy; // purple
    return AppColors.aqiVeryUnhealthy; // hitam
  }

  // Date & Time Helpers
  static String formatDateTime(DateTime dateTime, {String format = 'dd/MM/yyyy HH:mm'}) {
    return DateFormat(format).format(dateTime);
  }

  // Tambah method format baru untuk waktu update
  static String formatLastUpdate(DateTime dateTime) {
    // Konversi ke waktu lokal
    final localTime = dateTime.toLocal();
    return '  ${_formatLocalTime(localTime)}';
  }

  static String formatLastUpdateWithDate(DateTime dateTime) {
    // Konversi ke waktu lokal
    final localTime = dateTime.toLocal();
    final now = DateTime.now().toLocal();
    
    // Jika tanggal sama dengan hari ini
    if (localTime.year == now.year &&
        localTime.month == now.month &&
        localTime.day == now.day) {
      return 'Hari ini ${_formatLocalTime(localTime)}';
    }
    
    // Jika tanggal kemarin
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (localTime.year == yesterday.year &&
        localTime.month == yesterday.month &&
        localTime.day == yesterday.day) {
      return 'Kemarin ${_formatLocalTime(localTime)}';
    }
    
    // Format dengan tanggal (menggunakan format lokal)
    return DateFormat('dd/MM HH:mm').format(localTime);
  }

  static String _formatLocalTime(DateTime localTime) {
    // Format 24 jam
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String formatLocalTimeForDisplay(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    
    // Cek preferensi waktu 12/24 jam berdasarkan locale
    final format = DateFormat.Hm(); // Otomatis menggunakan 12/24 jam sesuai locale
    return format.format(localTime);
  }

  static String formatLocalTimeWithAmPm(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    final format = DateFormat('hh:mm a'); // Contoh: 02:30 PM
    return format.format(localTime);
  }

  static String formatLocalDateTimeFull(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    return DateFormat('dd MMM yyyy HH:mm').format(localTime); // Contoh: 15 Jan 2024 14:30
  }

  // Method untuk format real-time (akan diupdate setiap detik)
  static String formatRealTimeUpdate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    // Format yang berbeda berdasarkan berapa lama yang lalu
    if (difference.inSeconds < 10) {
      return 'Live • Baru saja';
    } else if (difference.inSeconds < 60) {
      return 'Live • ${difference.inSeconds} detik lalu';
    } else if (difference.inMinutes < 5) {
      return 'Live • ${difference.inMinutes} menit lalu';
    } else {
      return 'Terakhir update ${DateFormat('HH:mm').format(dateTime)}';
    }
  }

  // Method untuk format dengan indikator status
  static Map<String, dynamic> formatUpdateWithStatus(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    String text;
    Color color;
    IconData icon;
    
    if (difference.inSeconds < 30) {
      text = 'Live • ${DateFormat('HH:mm').format(dateTime)}';
      color = Colors.green;
      icon = Icons.circle;
    } else if (difference.inSeconds < 60) {
      text = 'Baru • ${DateFormat('HH:mm').format(dateTime)}';
      color = Colors.green;
      icon = Icons.circle;
    } else if (difference.inMinutes < 5) {
      text = 'Terakhir update ${DateFormat('HH:mm').format(dateTime)}';
      color = Colors.blue;
      icon = Icons.circle;
    } else if (difference.inMinutes < 15) {
      text = 'Terakhir update ${DateFormat('HH:mm').format(dateTime)}';
      color = Colors.orange;
      icon = Icons.circle;
    } else {
      text = 'Update lama • ${DateFormat('dd/MM HH:mm').format(dateTime)}';
      color = Colors.grey;
      icon = Icons.circle;
    }
    
    return {
      'text': text,
      'color': color,
      'icon': icon,
      'isRecent': difference.inMinutes < 5,
      'difference': difference
    };
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
  
  static String getAQICategory(int aqi) {
    if (aqi <= 50) return 'baik';
    if (aqi <= 100) return 'sedang';
    if (aqi <= 150) return 'tidak_sehat';
    if (aqi <= 200) return 'sangat_tidak_sehat';
    if (aqi <= 300) return 'berbahaya';
    return 'error';
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

  static List<String> getDetailedRecommendations(Room room) {
    final recommendations = <String>[];
    final data = room.currentData;

    // AQI based recommendations
    final aqi = room.currentAQI;
     if (aqi > 300) {
      recommendations.add('KONDISI SANGAT BERBAHAYA - TIDAK ADA AKTIVITAS AKADEMIK TATAP MUKA');
      recommendations.add('Tim manajemen gedung melakukan pemantauan AQI setiap jam');
      recommendations.add('Nyalakan air purifier dengan kecepatan maksimum selama 24 jam non-stop untuk membersihkan ruangan');
    }else if (aqi > 200) {
      recommendations.add('Kualitas udara dalam kelas sangat berbahaya untuk perkuliahan tatap muka');
      recommendations.add('Segera alihkan seluruh perkuliahan ke metode daring atau asynchronous');
      recommendations.add('Nyalakan air purifier dengan kecepatan maksimum selama 24 jam non-stop untuk membersihkan ruangan');
    }else if (aqi > 150) {
      recommendations.add('Kualitas udara dalam kelas buruk dan berisiko bagi semua penghuni ruangan');
      recommendations.add('Gunakan masker ketika berada di ruangan ini');
      recommendations.add('Wjib menyalakan air purifier di setiap kelas yang digunakan');
    } else if (aqi > 100) {
      recommendations.add('Kualitas udara dalam kelas mulai berdampak pada kelompok sensitif');
      recommendations.add('Kurangi aktivitas fisik berat');
      recommendations.add('Jika tersedia, nyalakan air purifier di dalam kelas');
    } else if (aqi > 50) {
      recommendations.add('Kualitas udara masih dapat diterima untuk perkuliahan');
      recommendations.add('Pastikan kelas dalam keadaan bersih, tidak ada debu berlebih di lantai, meja, atau AC');
    } else {
      recommendations.add('Kualitas udara sangat baik dan optimal untuk proses belajar mengajar');
      recommendations.add('Aman untuk perkuliahan dengan durasi berapapun');
    }
    
    // PM2.5 specific
    if (data.pm25 > 35.4) {
      recommendations.add('PM2.5 tinggi: Gunakan air purifier');
    }

     // PM10 specific
    if (data.pm10 > 100) {
      recommendations.add('PM10 tinggi: Bersihkan kelas secara basah sebelum perkuliahan');
    }
    
    // CO2 specific
    if (data.co2 > 1000) {
      recommendations.add('CO₂ tinggi: Buka jendela untuk ventilasi');
    }
    
    // Temperature specific
    if (data.temperature > 28) {
      recommendations.add('Suhu panas: Nyalakan AC atau kipas');
    } else if (data.temperature < 22) {
      recommendations.add('Suhu dingin: Gunakan pemanas ruangan');
    } 
    
    // Humidity specific
    if (data.humidity > 70) {
      recommendations.add('Kelembaban tinggi: Gunakan dehumidifier');
    } else if (data.humidity < 40) {
      recommendations.add('Kelembaban rendah: Gunakan humidifier');
    }
    
    return recommendations;
  }
}