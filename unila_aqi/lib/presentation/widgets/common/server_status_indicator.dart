import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/server_status_service.dart';

class ServerStatusIndicator extends StatefulWidget {
  final Duration pollInterval;
  final double size;

  const ServerStatusIndicator({
    super.key,
    this.pollInterval = const Duration(seconds: 10),
    this.size = 10,
  });

  static Future<bool> checkNow() => ServerStatusService().checkNow();

  @override
  State<ServerStatusIndicator> createState() => _ServerStatusIndicatorState();
}

class _ServerStatusIndicatorState extends State<ServerStatusIndicator> {
  final ServerStatusService _service = ServerStatusService();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Check pertama kali instan
    _service.checkNow();
    // Polling berkala sebagai fallback (refresh button tetap jalan
    // lewat static helper).
    _timer = Timer.periodic(widget.pollInterval, (_) => _service.checkNow());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool?>(
      valueListenable: _service.status,
      builder: (context, value, _) {
        final Color color;
        if (value == null) {
          color = Colors.grey;
        } else if (value == true) {
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
      },
    );
  }
}