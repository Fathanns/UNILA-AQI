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

 static String formatChartTime(DateTime date) {
  final localDate = date.toLocal();
  
  // Tentukan format berdasarkan rentang waktu
  final now = DateTime.now().toLocal();
  final difference = now.difference(localDate);
  
  if (difference.inHours < 24) {
    // Kurang dari 24 jam: tampilkan jam:menit
    return DateFormat('HH:mm').format(localDate);
  } else if (difference.inDays < 2) {
    // 24-48 jam: tampilkan "Kemarin HH:mm"
    return 'Kemarin ${DateFormat('HH:mm').format(localDate)}';
  } else {
    // Lebih dari 48 jam: tampilkan tanggal
    return DateFormat('dd/MM HH:mm').format(localDate);
  }
}
}