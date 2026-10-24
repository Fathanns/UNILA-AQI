import 'package:flutter/foundation.dart';
import 'api_service.dart';

class ServerStatusService {
  static final ServerStatusService _instance =
      ServerStatusService._internal();
  factory ServerStatusService() => _instance;
  ServerStatusService._internal();

  final ApiService _api = ApiService();

  /// `null` = belum pernah cek, `true` = online, `false` = offline.
  /// Di-notify setiap kali status berubah.
  final ValueNotifier<bool?> status = ValueNotifier<bool?>(null);

  bool _checking = false;

  /// Lakukan health check segera.
  /// Return hasil (true = online). Fire-and-forget juga aman —
  /// `status` akan otomatis di-update.
  Future<bool> checkNow() async {
    // Deduplicate: kalau check sedang berjalan, kembalikan nilai terakhir
    // tanpa menumpuk request baru. Ini mencegah race condition antara
    // polling timer dan tombol refresh.
    if (_checking) {
      return status.value ?? false;
    }

    _checking = true;
    try {
      final online = await _api.checkServerHealth();
      status.value = online;
      return online;
    } catch (_) {
      status.value = false;
      return false;
    } finally {
      _checking = false;
    }
  }

  /// Dipakai internal untuk testing / logging.
  bool get isChecking => _checking;
}