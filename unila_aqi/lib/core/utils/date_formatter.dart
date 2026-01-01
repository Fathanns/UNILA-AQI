import 'package:intl/intl.dart';

class DateFormatter {
  static String format(DateTime date, {String pattern = 'dd/MM/yyyy'}) {
    return DateFormat(pattern).format(date);
  }

  static String formatTime(DateTime date, {String pattern = 'HH:mm'}) {
    return DateFormat(pattern).format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inDays == 1) {
      return 'Kemarin';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari lalu';
    } else {
      return format(date);
    }
  }

  static String formatChartTime(DateTime date, String range) {
  // Konversi ke waktu lokal
  final localDate = date.toLocal();
  
  switch (range) {
    case '24h':
      return DateFormat('HH:mm').format(localDate); // Format 24 jam
    case '7d':
      return DateFormat('E').format(localDate); // Hari dalam seminggu (Sen, Sel, etc)
    case '30d':
      return DateFormat('dd/MM').format(localDate); // Tanggal/bulan
    default:
      return DateFormat('HH:mm').format(localDate);
  }
}
}