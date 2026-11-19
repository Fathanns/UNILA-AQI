import 'room.dart';

/// Helper untuk memproses payload realtime (socket.io) yang berisi data ruangan.
///
/// Dipakai oleh RoomProvider, Kelola Ruangan, dan Detail Ruangan supaya
/// semua layar memperbarui state dengan cara yang sama.
class RoomRealtime {
  RoomRealtime._();

  /// Ambil snapshot ruangan (`room`) dari payload, bila ada.
  static Map<String, dynamic>? snapshotOf(Map<String, dynamic> data) {
    final raw = data['room'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  /// Ambil roomId dari payload. Mendukung `roomId` maupun `room.id`.
  static String? roomIdOf(Map<String, dynamic> data) {
    final direct = data['roomId']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;

    final snap = snapshotOf(data);
    final id = snap?['id']?.toString() ?? snap?['_id']?.toString();
    return (id != null && id.isNotEmpty) ? id : null;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString())?.toLocal();
  }

  /// Gabungkan snapshot ke ruangan yang sudah ada.
  /// Bila [current] null, dibuat Room baru dari snapshot.
  /// Field yang tidak dikirim server dipertahankan dari [current].
  static Room merge(Room? current, Map<String, dynamic> snap) {
    final id = (snap['id'] ?? snap['_id'] ?? current?.id)?.toString() ?? '';
    final cdRaw = snap['currentData'];

    return Room(
      id: id,
      name: snap['name']?.toString() ?? current?.name ?? '',
      buildingId: snap['buildingId']?.toString() ?? current?.buildingId ?? '',
      buildingName:
          snap['buildingName']?.toString() ?? current?.buildingName ?? 'Unknown',
      iotDeviceId: snap.containsKey('iotDeviceId')
          ? snap['iotDeviceId']?.toString()
          : current?.iotDeviceId,
      iotDeviceName: snap.containsKey('iotDeviceName')
          ? snap['iotDeviceName']?.toString()
          : current?.iotDeviceName,
      currentAQI: snap.containsKey('currentAQI')
          ? _toInt(snap['currentAQI'])
          : current?.currentAQI,
      currentData: cdRaw is Map
          ? RoomData.fromJson(Map<String, dynamic>.from(cdRaw))
          : (current?.currentData ?? RoomData(updatedAt: DateTime.now())),
      createdAt: _toDate(snap['createdAt']) ?? current?.createdAt ?? DateTime.now(),
      updatedAt: _toDate(snap['updatedAt']) ?? DateTime.now(),
    );
  }
}