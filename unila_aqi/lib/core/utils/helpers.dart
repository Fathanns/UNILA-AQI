import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:unila_aqi/data/models/room.dart';
import '../constants/colors.dart';
import '../constants/app_constants.dart';

class Helpers {

  // ============================================================
  // ERROR / NETWORK HELPERS
  // ============================================================
  static bool isNetworkError(dynamic error) {
    final s = (error?.toString() ?? '').toLowerCase();
    return s.contains('socketexception') ||
        s.contains('clientexception') ||
        s.contains('network error') ||
        s.contains('failed host lookup') ||
        s.contains('host lookup') ||
        s.contains('no route to host') ||
        s.contains('connection refused') ||
        s.contains('connection closed') ||
        s.contains('connection reset') ||
        s.contains('connection error') ||
        s.contains('connection failed') ||
        s.contains('xmlhttprequest') ||
        s.contains('timeout') ||
        s.contains('unable to connect') ||
        s.contains('typeerror: failed to fetch');
  }

  static void showServerError(BuildContext context) {
    showSnackBar(
      context,
      'Tidak dapat terhubung ke server. Periksa koneksi internet Anda atau coba beberapa saat lagi.',
      isError: true,
    );
  }

  static String friendlyErrorMessage(dynamic error) {
    if (isNetworkError(error)) {
      return 'Tidak dapat terhubung ke server.\nPeriksa koneksi internet Anda atau coba beberapa saat lagi.';
    }
    return 'Terjadi kesalahan saat memuat data.\nSilakan coba lagi.';
  }

  /// ✅ FIX: filter noisy tokens diperluas + buang semua prefix teknis
  static String extractBackendMessage(
    dynamic error, {
    required String fallback,
  }) {
    String msg = (error?.toString() ?? '').trim();
    msg = msg.replaceFirst('Exception: ', '').trim();

    final lower = msg.toLowerCase();

    const noisyTokens = [
      'clientexception',
      'socketexception',
      'http exception',
      'httpexception',
      'xmlhttprequest',
      'instance of',
      'failed host lookup',
      'stacktrace',
      'stack trace',
      'mongooseerror',
      'cast to objectid',
      'typeerror',
      'null check operator',
    ];
    final hasNoise = noisyTokens.any(lower.contains);

    if (msg.isEmpty || isNetworkError(error) || hasNoise) {
      return fallback;
    }
    return msg;
  }

  // ============================================================
  // AQI HELPERS — PP 22/2021
  // ============================================================
  static bool isErrorAQI(int? aqi) => aqi != null && aqi < 0;

   static Color getAQIColor(int? aqi) {
    if (aqi == null) return AppColors.aqiNoData;
    if (aqi < 0) return AppColors.aqiError;
    if (aqi <= 50) return AppColors.aqiGood;
    if (aqi <= 100) return AppColors.aqiModerate;
    if (aqi <= 200) return AppColors.aqiUnhealthySensitive;
    if (aqi <= 300) return AppColors.aqiUnhealthy;
    return AppColors.aqiHazardous;
  }

  static String getAQILabel(int? aqi) {
    if (aqi == null) return 'TIDAK ADA DATA';
    if (aqi < 0) return 'ERROR';
    if (aqi <= 50) return 'BAIK';
    if (aqi <= 100) return 'SEDANG';
    if (aqi <= 200) return 'TIDAK SEHAT';
    if (aqi <= 300) return 'SANGAT TIDAK SEHAT';
    return 'BERBAHAYA';
  }

  static String getAQIHealthMessage(int? aqi) {
    if (aqi == null) {
      return 'Belum ada data valid dari perangkat.';
    }
    if (aqi < 0) {
      return 'Sensor ruangan melaporkan error. Nilai AQI yang ditampilkan adalah nilai valid terakhir.';
    }
    if (aqi <= 50) return AppConstants.healthRecommendations['good']!;
    if (aqi <= 100) return AppConstants.healthRecommendations['moderate']!;
    if (aqi <= 200) return AppConstants.healthRecommendations['unhealthy']!;
    if (aqi <= 300) return AppConstants.healthRecommendations['very_unhealthy']!;
    return AppConstants.healthRecommendations['dangerous']!;
  }

  // PM2.5
  static String getPM25Status(double? v) {
    if (v == null) return 'DATA TIDAK DITERIMA';
    if (v < 0) return 'ERROR';
    if (v <= 55) return 'BAIK';
    if (v <= 150) return 'SEDANG';
    if (v <= 250) return 'TIDAK SEHAT';
    if (v <= 350) return 'SANGAT TIDAK SEHAT';
    return 'BERBAHAYA';
  }
  static Color getPM25Color(double? v) {
    if (v == null) return AppColors.aqiNoData;
    if (v < 0) return AppColors.aqiError;
    if (v <= 55) return AppColors.aqiGood;
    if (v <= 150) return AppColors.aqiModerate;
    if (v <= 250) return AppColors.aqiUnhealthySensitive;
    if (v <= 350) return AppColors.aqiUnhealthy;
    return AppColors.aqiHazardous;
  }

  // PM10
  static String getPM10Status(double? v) {
    if (v == null) return 'DATA TIDAK DITERIMA';
    if (v < 0) return 'ERROR';
    if (v <= 50) return 'BAIK';
    if (v <= 150) return 'SEDANG';
    if (v <= 350) return 'TIDAK SEHAT';
    if (v <= 420) return 'SANGAT TIDAK SEHAT';
    return 'BERBAHAYA';
  }
  static Color getPM10Color(double? v) {
    if (v == null) return AppColors.aqiNoData;
    if (v < 0) return AppColors.aqiError;
    if (v <= 50) return AppColors.aqiGood;
    if (v <= 150) return AppColors.aqiModerate;
    if (v <= 350) return AppColors.aqiUnhealthySensitive;
    if (v <= 420) return AppColors.aqiUnhealthy;
    return AppColors.aqiHazardous;
  }

  // CO
  static String getCOStatus(double? v) {
    if (v == null) return 'DATA TIDAK DITERIMA';
    if (v < 0) return 'ERROR';
    if (v <= 4000) return 'BAIK';
    if (v <= 8000) return 'SEDANG';
    if (v <= 15000) return 'TIDAK SEHAT';
    if (v <= 30000) return 'SANGAT TIDAK SEHAT';
    return 'BERBAHAYA';
  }
  static Color getCOColor(double? v) {
    if (v == null) return AppColors.aqiNoData;
    if (v < 0) return AppColors.aqiError;
    if (v <= 4000) return AppColors.aqiGood;
    if (v <= 8000) return AppColors.aqiModerate;
    if (v <= 15000) return AppColors.aqiUnhealthySensitive;
    if (v <= 30000) return AppColors.aqiUnhealthy;
    return AppColors.aqiHazardous;
  }

  // SO2
  static String getSO2Status(double? v) {
    if (v == null) return 'DATA TIDAK DITERIMA';
    if (v < 0) return 'ERROR';
    if (v <= 80) return 'BAIK';
    if (v <= 365) return 'SEDANG';
    if (v <= 800) return 'TIDAK SEHAT';
    if (v <= 1600) return 'SANGAT TIDAK SEHAT';
    return 'BERBAHAYA';
  }
  static Color getSO2Color(double? v) {
    if (v == null) return AppColors.aqiNoData;
    if (v < 0) return AppColors.aqiError;
    if (v <= 80) return AppColors.aqiGood;
    if (v <= 365) return AppColors.aqiModerate;
    if (v <= 800) return AppColors.aqiUnhealthySensitive;
    if (v <= 1600) return AppColors.aqiUnhealthy;
    return AppColors.aqiHazardous;
  }

  // O3
  static String getO3Status(double? v) {
    if (v == null) return 'DATA TIDAK DITERIMA';
    if (v < 0) return 'ERROR';
    if (v <= 120) return 'BAIK';
    if (v <= 235) return 'SEDANG';
    if (v <= 400) return 'TIDAK SEHAT';
    if (v <= 800) return 'SANGAT TIDAK SEHAT';
    return 'BERBAHAYA';
  }
  static Color getO3Color(double? v) {
    if (v == null) return AppColors.aqiNoData;
    if (v < 0) return AppColors.aqiError;
    if (v <= 120) return AppColors.aqiGood;
    if (v <= 235) return AppColors.aqiModerate;
    if (v <= 400) return AppColors.aqiUnhealthySensitive;
    if (v <= 800) return AppColors.aqiUnhealthy;
    return AppColors.aqiHazardous;
  }

  // NO2
  static String getNO2Status(double? v) {
    if (v == null) return 'DATA TIDAK DITERIMA';
    if (v < 0) return 'ERROR';
    if (v <= 80) return 'BAIK';
    if (v <= 200) return 'SEDANG';
    if (v <= 1130) return 'TIDAK SEHAT';
    if (v <= 2260) return 'SANGAT TIDAK SEHAT';
    return 'BERBAHAYA';
  }
  static Color getNO2Color(double? v) {
    if (v == null) return AppColors.aqiNoData;
    if (v < 0) return AppColors.aqiError;
    if (v <= 80) return AppColors.aqiGood;
    if (v <= 200) return AppColors.aqiModerate;
    if (v <= 1130) return AppColors.aqiUnhealthySensitive;
    if (v <= 2260) return AppColors.aqiUnhealthy;
    return AppColors.aqiHazardous;
  }

  // Temperature
  static String getTemperatureStatus(double? v) {
    if (v == null) return 'DATA TIDAK DITERIMA';
    if (v < 0) return 'ERROR';
    if (v < 24) return 'DINGIN';
    if (v <= 27) return 'IDEAL';
    if (v <= 30) return 'HANGAT';
    return 'PANAS';
  }
  static Color getTemperatureColor(double? v) {
    if (v == null) return AppColors.aqiNoData;
    if (v < 0) return AppColors.aqiError;
    if (v < 24) return Colors.blue;
    if (v <= 27) return AppColors.success;
    if (v <= 30) return AppColors.warning;
    return AppColors.error;
  }

  // Humidity
  static String getHumidityStatus(double? v) {
    if (v == null) return 'DATA TIDAK DITERIMA';
    if (v < 0) return 'ERROR';
    if (v < 40) return 'KERING';
    if (v <= 60) return 'IDEAL';
    if (v <= 70) return 'LEMBAB';
    return 'TIDAK NYAMAN';
  }
  static Color getHumidityColor(double? v) {
    if (v == null) return AppColors.aqiNoData;
    if (v < 0) return AppColors.aqiError;
    if (v < 40) return AppColors.aqiUnhealthySensitive;
    if (v <= 60) return AppColors.aqiGood;
    if (v <= 70) return AppColors.aqiModerate;
    return AppColors.aqiUnhealthy;
  }

  // ============================================================
  // DATE & TIME HELPERS
  // ============================================================
  static String formatDateTime(DateTime dateTime, {String format = 'dd/MM/yyyy HH:mm'}) {
    return DateFormat(format).format(dateTime);
  }

  static String formatLastUpdate(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    final now = DateTime.now().toLocal();

    if (localTime.year == now.year &&
        localTime.month == now.month &&
        localTime.day == now.day) {
      return '  ${_formatLocalTime(localTime)}';
    }

    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (localTime.year == yesterday.year &&
        localTime.month == yesterday.month &&
        localTime.day == yesterday.day) {
      return 'Kemarin ${_formatLocalTime(localTime)}';
    }

    return DateFormat('dd/MM HH:mm').format(localTime);
  }

  static String formatLastUpdateWithDate(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    final now = DateTime.now().toLocal();

    if (localTime.year == now.year &&
        localTime.month == now.month &&
        localTime.day == now.day) {
      return 'Hari ini ${_formatLocalTime(localTime)}';
    }

    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (localTime.year == yesterday.year &&
        localTime.month == yesterday.month &&
        localTime.day == yesterday.day) {
      return 'Kemarin ${_formatLocalTime(localTime)}';
    }

    return DateFormat('dd/MM HH:mm').format(localTime);
  }

  static String _formatLocalTime(DateTime localTime) {
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String formatLocalTimeForDisplay(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    return DateFormat.Hm().format(localTime);
  }

  static String formatLocalTimeWithAmPm(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    return DateFormat('hh:mm a').format(localTime);
  }

  static String formatLocalDateTimeFull(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    return DateFormat('dd MMM yyyy HH:mm').format(localTime);
  }

  static String formatRealTimeUpdate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

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

  static Map<String, String> formatCompactLastUpdate(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    final now = DateTime.now().toLocal();
    final timeStr = _formatLocalTime(localTime);

    if (localTime.year == now.year &&
        localTime.month == now.month &&
        localTime.day == now.day) {
      return {'label': 'HARI INI', 'time': timeStr};
    }

    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (localTime.year == yesterday.year &&
        localTime.month == yesterday.month &&
        localTime.day == yesterday.day) {
      return {'label': 'KEMARIN', 'time': timeStr};
    }

    return {
      'label': DateFormat('dd/MM').format(localTime),
      'time': timeStr,
    };
  }

  // ============================================================
  // UI HELPERS
  // ============================================================
  static void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  // ============================================================
  // VALIDATION HELPERS
  // ============================================================
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  static bool isValidPassword(String password) {
    return password.length >= 8;
  }

  // ============================================================
  // STRING HELPERS
  // ============================================================
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  static String truncateWithEllipsis(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  // ============================================================
  // JSON HELPERS
  // ============================================================
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

  // ============================================================
  // NETWORK / COLOR HELPERS
  // ============================================================
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

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
    final aqi = room.currentAQI;

    // 0. NO DATA
    if (aqi == null) {
      recommendations.add('BELUM ADA DATA');
      recommendations.add(
          'Perangkat belum mengirimkan data yang valid. Data akan muncul setelah polling berhasil.');
      recommendations.add(
          'Jika kondisi ini berlangsung lama, hubungi admin untuk memeriksa perangkat.');
      return recommendations;
    }

    // 0b. SENSOR ERROR
    if (aqi < 0) {
      recommendations.add('SENSOR RUANGAN MELAPORKAN ERROR');
      recommendations.add(
          'Nilai AQI yang ditampilkan adalah nilai valid terakhir sebelum sensor bermasalah');
      recommendations.add(
          'Hubungi admin untuk memeriksa perangkat sensor pada ruangan ini');
      return recommendations;
    }

    // 1. AQI
    if (aqi <= 50) {
      recommendations.add(
          'AQI: Aman untuk perkuliahan normal dengan durasi berapa pun. Tidak perlu tindakan khusus.');
    } else if (aqi <= 100) {
      recommendations.add(
          'AQI: Perkuliahan tatap muka tetap aman. Pastikan ruangan bebas debu berlebih. Kelompok sensitif sebaiknya tidak duduk dekat jendela/sumber polusi.');
    } else if (aqi <= 200) {
      recommendations.add(
          'AQI: Kurangi aktivitas fisik berat di ruangan. Nyalakan air purifier bila tersedia. Pertimbangkan memindahkan kelas ke ruangan dengan ventilasi lebih baik.');
    } else if (aqi <= 300) {
      recommendations.add(
          'AQI: Wajib memakai masker di dalam ruangan. Nyalakan air purifier kecepatan maksimum. Batasi durasi tatap muka.');
    } else {
      recommendations.add(
          'AQI: Tidak ada aktivitas akademik tatap muka. Alihkan seluruhnya ke daring.');
    }

    // 2. PM2.5
    final pm25 = data.pm25;
    if (pm25 != null && pm25 >= 0) {
      if (pm25 <= 55) {
        recommendations.add('PM2.5: Aman untuk perkuliahan. Jaga kebersihan lantai dan meja.');
      } else if (pm25 <= 150) {
        recommendations.add(
            'PM2.5: Nyalakan air purifier bila ada. Hindari aktivitas berdebu.');
      } else if (pm25 <= 250) {
        recommendations.add(
            'PM2.5: Wajib nyalakan air purifier. Masker disarankan. Tutup jendela.');
      } else if (pm25 <= 350) {
        recommendations.add(
            'PM2.5: Masker wajib (surgical/N95). Air purifier kecepatan maksimum.');
      } else {
        recommendations.add(
            'PM2.5: Tidak ada aktivitas tatap muka. Evakuasi ruangan bila perlu.');
      }
    }

    // 3. PM10
    final pm10 = data.pm10;
    if (pm10 != null && pm10 >= 0) {
      if (pm10 <= 50) {
        recommendations.add('PM10: Aman. Jaga kebersihan lantai dan meja.');
      } else if (pm10 <= 150) {
        recommendations.add(
            'PM10: Bersihkan kelas secara basah (pel basah) sebelum perkuliahan.');
      } else if (pm10 <= 350) {
        recommendations.add(
            'PM10: Masker disarankan. Nyalakan air purifier. Tutup jendela.');
      } else if (pm10 <= 420) {
        recommendations.add(
            'PM10: Masker wajib. Air purifier kecepatan maksimum. Batasi aktivitas fisik.');
      } else {
        recommendations.add(
            'PM10: Tidak ada aktivitas tatap muka. Evakuasi. Investigasi sumber debu.');
      }
    }

    // 4. CO
    final co = data.co;
    if (co != null && co >= 0) {
      if (co <= 4000) {
        recommendations.add('CO: Aman untuk perkuliahan normal.');
      } else if (co <= 8000) {
        recommendations.add(
            'CO: Pastikan ventilasi mekanis/AC fresh air berjalan.');
      } else if (co <= 15000) {
        recommendations.add(
            'CO: Buka jendela/pintu untuk ventilasi silang. Nyalakan exhaust fan.');
      } else if (co <= 30000) {
        recommendations.add(
            'CO: Ventilasi darurat — buka semua akses udara, exhaust maksimum.');
      } else {
        recommendations.add(
            'CO: Evakuasi ruangan. Investigasi segera (sistem HVAC, kebocoran).');
      }
    }

    // 5. SO2
    final so2 = data.so2;
    if (so2 != null && so2 >= 0) {
      if (so2 <= 80) {
        recommendations.add('SO2: Aman untuk perkuliahan normal.');
      } else if (so2 <= 365) {
        recommendations.add(
            'SO2: Pastikan ventilasi ruangan baik. Hindari sumber pembakaran di sekitar ruangan.');
      } else if (so2 <= 800) {
        recommendations.add(
            'SO2: Nyalakan ventilasi/exhaust. Masker disarankan. Kurangi aktivitas fisik berat.');
      } else if (so2 <= 1600) {
        recommendations.add(
            'SO2: Masker wajib. Ventilasi maksimum. Pertimbangkan relokasi kelas atau daring.');
      } else {
        recommendations.add(
            'SO2: Evakuasi ruangan. Investigasi sumber gas sulfur segera.');
      }
    }

    // 6. O3
    final o3 = data.o3;
    if (o3 != null && o3 >= 0) {
      if (o3 <= 120) {
        recommendations.add('O3: Aman untuk perkuliahan normal.');
      } else if (o3 <= 235) {
        recommendations.add(
            'O3: Kelompok sensitif sebaiknya mengurangi aktivitas fisik berat.');
      } else if (o3 <= 400) {
        recommendations.add(
            'O3: Kurangi aktivitas fisik berat. Masker disarankan. Nyalakan air purifier bila ada.');
      } else if (o3 <= 800) {
        recommendations.add(
            'O3: Masker wajib. Batasi durasi tatap muka. Pertimbangkan daring.');
      } else {
        recommendations.add(
            'O3: Tidak ada aktivitas tatap muka. Evakuasi ruangan. Investigasi sumber ozon.');
      }
    }

    // 7. NO2
    final no2 = data.no2;
    if (no2 != null && no2 >= 0) {
      if (no2 <= 80) {
        recommendations.add('NO2: Aman untuk perkuliahan normal.');
      } else if (no2 <= 200) {
        recommendations.add(
            'NO2: Pastikan ventilasi baik. Hindari sumber pembakaran di dalam ruangan.');
      } else if (no2 <= 1130) {
        recommendations.add(
            'NO2: Nyalakan exhaust/ventilasi. Masker disarankan. Kurangi kapasitas ruangan.');
      } else if (no2 <= 2260) {
        recommendations.add(
            'NO2: Masker wajib. Ventilasi darurat. Pertimbangkan mengosongkan ruangan sementara.');
      } else {
        recommendations.add(
            'NO2: Evakuasi ruangan. Investigasi kebocoran gas/sistem HVAC segera.');
      }
    }

    // 8. Suhu
    final temp = data.temperature;
    if (temp != null && temp >= 0) {
      if (temp < 24) {
        recommendations.add(
            'Suhu: Nyalakan pemanas ruangan bila tersedia. Pakai pakaian hangat.');
      } else if (temp <= 27) {
        recommendations.add('Suhu: Kondisi optimal untuk belajar. Tidak perlu tindakan.');
      } else if (temp <= 30) {
        recommendations.add(
            'Suhu: Nyalakan AC atau kipas. Pastikan sirkulasi udara baik.');
      } else {
        recommendations.add(
            'Suhu: AC/kipas wajib. Buka ventilasi bila AC tidak tersedia. Sediakan air minum.');
      }
    }

    // 9. Kelembaban
    final humidity = data.humidity;
    if (humidity != null && humidity >= 0) {
      if (humidity < 40) {
        recommendations.add(
            'Kelembaban: Gunakan humidifier. Sediakan air minum.');
      } else if (humidity <= 60) {
        recommendations.add('Kelembaban: Kondisi optimal. Tidak perlu tindakan.');
      } else if (humidity <= 70) {
        recommendations.add(
            'Kelembaban: Nyalakan dehumidifier atau AC mode dry. Pastikan ventilasi baik.');
      } else {
        recommendations.add(
            'Kelembaban: Dehumidifier wajib. Tingkatkan ventilasi. Risiko jamur & tungau meningkat.');
      }
    }

    return recommendations;
  }
}