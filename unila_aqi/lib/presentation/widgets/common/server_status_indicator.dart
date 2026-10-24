import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';

/// Indikator titik kecil hijau (online) / merah (offline) /
/// abu-abu (sedang cek pertama kali).
///
/// Auto polling setiap [pollInterval] (default 10 detik).
class ServerStatusIndicator extends StatefulWidget {
  final Duration pollInterval;
  final double size;

  const ServerStatusIndicator({
    super.key,
    this.pollInterval = const Duration(seconds: 10),
    this.size = 10,
  });

  @override
  State<ServerStatusIndicator> createState() => _ServerStatusIndicatorState();
}

class _ServerStatusIndicatorState extends State<ServerStatusIndicator> {
  final ApiService _api = ApiService();
  Timer? _timer;
  bool? _isOnline; // null = belum pernah cek
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _check();
    _timer = Timer.periodic(widget.pollInterval, (_) => _check());
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;

    final online = await _api.checkServerHealth();
    _checking = false;

    if (!mounted) return;
    if (_isOnline != online) {
      setState(() => _isOnline = online);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (_isOnline == null) {
      color = Colors.grey;
    } else if (_isOnline == true) {
      color = Colors.green;
    } else {
      color = Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.55),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}