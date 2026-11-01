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
  static bool isErrorAQI(int aqi) => aqi < 0;

  static Color getAQIColor(int aqi) {
    if (aqi < 0) return AppColors.aqiError;
    if (aqi <= 50) return AppColors.aqiGood;
    if (aqi <= 100) return AppColors.aqiModerate;
    if (aqi <= 200) return AppColors.aqiUnhealthySensitive;
    if (aqi <= 300) return AppColors.aqiUnhealthy;
    return AppColors.aqiHazardous;
  }

  static String getAQILabel(int aqi) {
    if (aqi < 0) return 'ERROR';
    if (aqi <= 50) return 'BAIK';
    if (aqi <= 100) return 'SEDANG';
    if (aqi <= 200) return 'TIDAK SEHAT';
    if (aqi <= 300) return 'SANGAT TIDAK SEHAT';
    return 'BERBAHAYA';
  }

  static String getAQIHealthMessage(int aqi) {
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
  static String getPM25Status(double value) {
    if (value < 0) return 'ERROR';
    if (value <= 55) return 'BAIK';
    if (value <= 150) return 'SEDANG';
    if (value <= 250) return 'TIDAK SEHAT';
    if (value <= 350) return 'SANGAT TIDAK SEHAT';
    return 'BERBAHAYA';
  }

  static Color getPM25Color(double value) {
    if (value < 0) return AppColors.aqiError;
    if (value <= 55) return AppColors.aqiGood;
    if (value <= 150) return AppColors.aqiModerate;
    if (value <= 250) return AppColors.aqiUnhealthySensitive;
    if (value <= 350) return AppColors.aqiUnhealthy;
    return AppColors.aqiHazardous;
  }

  // PM10
  static String getPM10Status(double value) {
    if (value < 0) return 'ERROR';
    if (value <= 50) return 'BAIK';
    if (value <= 150) return 'SEDANG';
    if (value <= 350) return 'TIDAK SEHAT';
    if (value <= 420) return 'SANGAT TIDAK SEHAT';
    return 'BERBAHAYA';
  }

  static Color getPM10Color(double value) {
    if (value < 0) return AppColors.aqiError;
    if (value <= 50) return AppColors.aqiGood;
    if (value <= 150) return AppColors.aqiModerate;
    if (value <= 350) return AppColors.aqiUnhealthySensitive;
    if (value <= 420) return AppColors.aqiUnhealthy;
    return AppColors.aqiHazardous;
  }

  // Temperature
  static String getTemperatureStatus(double value) {
    if (value < 0) return 'ERROR';
    if (value < 24) return 'DINGIN';
    if (value <= 27) return 'IDEAL';
    if (value <= 30) return 'HANGAT';
    return 'PANAS';
  }

  static Color getTemperatureColor(double value) {
    if (value < 0) return AppColors.aqiError;
    if (value < 24) return Colors.blue;
    if (value <= 27) return AppColors.success;
    if (value <= 30) return AppColors.warning;
    return AppColors.error;
  }

  // Humidity
  static String getHumidityStatus(double value) {
    if (value < 0) return 'ERROR';
    if (value < 40) return 'KERING';
    if (value <= 60) return 'IDEAL';
    if (value <= 70) return 'LEMBAB';
    return 'TIDAK NYAMAN';
  }

  static Color getHumidityColor(double value) {
    if (value < 0) return AppColors.aqiError;
    if (value < 40) return AppColors.aqiUnhealthySensitive;
    if (value <= 60) return AppColors.aqiGood;
    if (value <= 70) return AppColors.aqiModerate;
    return AppColors.aqiUnhealthy;
  }

   // CO
  static String getCOStatus(double value) { 
    if (value < 0) return 'ERROR';
    if (value <= 4000) return 'BAIK';
    if (value <= 8000) return 'SEDANG';
    if (value <= 15000) return 'TIDAK SEHAT';
    if (value <= 30000) return 'SANGAT TIDAK SEHAT';
    return 'BERBAHAYA';
  }

   static Color getCOColor(double value) { 
    if (value < 0) return AppColors.aqiError;
    if (value <= 4000) return AppColors.aqiGood;
    if (value <= 8000) return AppColors.aqiModerate;
    if (value <= 15000) return AppColors.aqiUnhealthySensitive;
    if (value <= 30000) return AppColors.aqiUnhealthy;
    return AppColors.aqiHazardous;
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

    // 0. SENSOR ERROR
    if (aqi < 0) {
      recommendations.add('SENSOR RUANGAN MELAPORKAN ERROR');
      recommendations.add(
          'Nilai AQI yang ditampilkan adalah nilai valid terakhir sebelum sensor bermasalah');
      recommendations
          .add('Hubungi admin untuk memeriksa perangkat sensor pada ruangan ini');
      return recommendations;
    }

    // 1. AQI / ISPU — PP 22/2021
    if (aqi <= 50) {
      recommendations.add(
          'AQI: Aman untuk perkuliahan normal dengan durasi berapa pun. Tidak perlu tindakan khusus.');
    } else if (aqi <= 100) {
      recommendations.add(
          'AQI: Perkuliahan tatap muka tetap aman. Pastikan ruangan bebas debu berlebih di lantai, meja, dan filter AC. Kelompok sensitif (asma, ibu hamil, lansia) sebaiknya tidak duduk dekat jendela/sumber polusi.');
    } else if (aqi <= 200) {
      recommendations.add(
          'AQI: Kurangi aktivitas fisik berat di ruangan. Nyalakan air purifier bila tersedia. Mahasiswa dengan riwayat pernapasan disarankan memakai masker. Pertimbangkan memindahkan kelas ke ruangan dengan ventilasi lebih baik.');
    } else if (aqi <= 300) {
      recommendations.add(
          'AQI: Wajib memakai masker di dalam ruangan. Nyalakan air purifier kecepatan maksimum. Batasi durasi tatap muka. Pertimbangkan mengalihkan kelas ke daring/async atau pindah ke ruangan ber-AC terpusat dengan filtrasi HEPA.');
    } else {
      recommendations.add(
          'AQI: Tidak ada aktivitas akademik tatap muka. Alihkan seluruhnya ke daring. Tim gedung pantau AQI setiap jam. Air purifier kecepatan maksimum 24 jam non-stop sampai AQI turun.');
    }

    // 2. PM2.5 — PP 22/2021 ISPU
    final pm25 = data.pm25;
    if (pm25 >= 0) {
      if (pm25 <= 55) {
        recommendations.add(
            'PM2.5: Aman untuk perkuliahan. Jaga kebersihan lantai dan meja.');
      } else if (pm25 <= 150) {
        recommendations.add(
            'PM2.5: Nyalakan air purifier bila ada. Hindari aktivitas berdebu (menyapu kering, buka jendela saat lalu lintas padat).');
      } else if (pm25 <= 250) {
        recommendations.add(
            'PM2.5: Wajib nyalakan air purifier. Masker disarankan. Tutup jendela. Bersihkan filter AC/purifier.');
      } else if (pm25 <= 350) {
        recommendations.add(
            'PM2.5: Masker wajib (surgical/N95). Air purifier kecepatan maksimum. Pertimbangkan relokasi kelas atau daring.');
      } else {
        recommendations.add(
            'PM2.5: Tidak ada aktivitas tatap muka. Evakuasi ruangan bila perlu. Air purifier 24 jam. Investigasi sumber polusi.');
      }
    }

    // 3. PM10 — PP 22/2021 ISPU
    final pm10 = data.pm10;
    if (pm10 >= 0) {
      if (pm10 <= 50) {
        recommendations.add(
            'PM10: Aman. Jaga kebersihan lantai dan meja.');
      } else if (pm10 <= 150) {
        recommendations.add(
            'PM10: Bersihkan kelas secara basah (pel basah) sebelum perkuliahan. Hindari menyapu kering. Pastikan filter AC bersih.');
      } else if (pm10 <= 350) {
        recommendations.add(
            'PM10: Masker disarankan. Nyalakan air purifier. Tutup jendela. Pel basah lebih sering.');
      } else if (pm10 <= 420) {
        recommendations.add(
            'PM10: Masker wajib. Air purifier kecepatan maksimum. Batasi aktivitas fisik. Pertimbangkan daring.');
      } else {
        recommendations.add(
            'PM10: Tidak ada aktivitas tatap muka. Evakuasi. Investigasi sumber debu (renovasi/jalan raya/gudang).');
      }
    }

    // 4. CO
    final co = data.co; 
    if (co >= 0) {
      if (co <= 4000) {
        recommendations.add(
            'CO: Aman untuk perkuliahan normal.');
      } else if (co <= 8000) {
        recommendations.add(
            'CO: Pastikan ventilasi mekanis/AC fresh air berjalan. Bila memungkinkan buka pintu/jendela sesaat.');
      } else if (co <= 15000) {
        recommendations.add(
            'CO: Buka jendela/pintu untuk ventilasi silang. Nyalakan exhaust fan. Kurangi kapasitas mahasiswa di ruangan.');
      } else if (co <= 30000) {
        recommendations.add(
            'CO: Ventilasi darurat — buka semua akses udara, exhaust maksimum. Pertimbangkan mengosongkan ruangan sementara.');
      } else {
        recommendations.add(
            'CO: Evakuasi ruangan. Investigasi segera (sistem HVAC, kebocoran, ruangan tertutup terlalu lama).');
      }
    }

    // 5. Suhu — SNI 03-6572-2001 & Permenaker 5/2018
    final temp = data.temperature;
    if (temp >= 0) {
      if (temp < 24) {
        recommendations.add(
            'Suhu: Nyalakan pemanas ruangan bila tersedia. Pakai pakaian hangat. Hindari duduk dekat AC/ventilasi dingin.');
      } else if (temp <= 27) {
        recommendations.add(
            'Suhu: Kondisi optimal untuk belajar. Tidak perlu tindakan.');
      } else if (temp <= 30) {
        recommendations.add(
            'Suhu: Nyalakan AC atau kipas. Pastikan sirkulasi udara baik. Sediakan air minum.');
      } else {
        recommendations.add(
            'Suhu: AC/kipas wajib. Buka ventilasi bila AC tidak tersedia. Sediakan air minum. Pertimbangkan relokasi ke ruangan ber-AC.');
      }
    }

    // 6. Kelembaban — SNI 03-6572-2001 & Permenaker 5/2018
    final humidity = data.humidity;
    if (humidity >= 0) {
      if (humidity < 40) {
        recommendations.add(
            'Kelembaban: Gunakan humidifier. Sediakan air minum. Hindari AC terlalu dingin yang mengeringkan udara.');
      } else if (humidity <= 60) {
        recommendations.add(
            'Kelembaban: Kondisi optimal. Tidak perlu tindakan.');
      } else if (humidity <= 70) {
        recommendations.add(
            'Kelembaban: Nyalakan dehumidifier atau AC mode dry. Pastikan ventilasi baik. Waspada jamur pada dinding/AC.');
      } else {
        recommendations.add(
            'Kelembaban: Dehumidifier wajib. Tingkatkan ventilasi. Periksa kebocoran/kelembaban dinding. Risiko jamur & tungau meningkat.');
      }
    }

    return recommendations;
  }
}