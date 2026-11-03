import 'package:flutter/material.dart';
import '../../../data/models/room.dart';
import '../../../core/utils/helpers.dart';

class RoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback? onTap;

  const RoomCard({
    super.key,
    required this.room,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final aqiColor = Helpers.getAQIColor(room.currentAQI);
    final aqiLabel = Helpers.getAQILabel(room.currentAQI);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row - Room name and building
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF212529),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          room.buildingName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6C757D),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Status indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: aqiColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: aqiColor),
                    ),
                    child: Text(
                      aqiLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: aqiColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // AQI Large Display - dengan background warna AQI
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: aqiColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Large AQI number
                    Text(
                      room.currentAQI.toString(),
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 0.9,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // AQI Label
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'INDEKS KUALITAS UDARA',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Parameter Grid - 2 rows, 3 columns
              GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: [
                  _buildParameterCell(
                    label: 'PM2.5',
                    value: room.currentData.pm25.toStringAsFixed(1),
                    unit: 'µg/m³',
                    status: Helpers.getPM25Status(room.currentData.pm25),
                    color: Helpers.getPM25Color(room.currentData.pm25),
                  ),
                  _buildParameterCell(
                    label: 'PM10',
                    value: room.currentData.pm10.toStringAsFixed(1),
                    unit: 'µg/m³',
                    status: Helpers.getPM10Status(room.currentData.pm10),
                    color: Helpers.getPM10Color(room.currentData.pm10),
                  ),
                  _buildParameterCell(
                    label: 'CO',
                    value: room.currentData.co.round().toString(),
                    unit: 'µg/m³',
                    status: Helpers.getCOStatus(room.currentData.co),
                    color: Helpers.getCOColor(room.currentData.co),
                  ),

                  // PARTIKEL BARU — hanya tampil jika data tersedia
                  if (room.currentData.so2 != null)
                    _buildParameterCell(
                      label: 'SO2',
                      value: room.currentData.so2!.toStringAsFixed(1),
                      unit: 'µg/m³',
                      status: Helpers.getSO2Status(room.currentData.so2!),
                      color: Helpers.getSO2Color(room.currentData.so2!),
                    ),
                  if (room.currentData.o3 != null)
                    _buildParameterCell(
                      label: 'O3',
                      value: room.currentData.o3!.toStringAsFixed(1),
                      unit: 'µg/m³',
                      status: Helpers.getO3Status(room.currentData.o3!),
                      color: Helpers.getO3Color(room.currentData.o3!),
                    ),
                  if (room.currentData.no2 != null)
                    _buildParameterCell(
                      label: 'NO2',
                      value: room.currentData.no2!.toStringAsFixed(1),
                      unit: 'µg/m³',
                      status: Helpers.getNO2Status(room.currentData.no2!),
                      color: Helpers.getNO2Color(room.currentData.no2!),
                    ),

                  _buildParameterCell(
                    label: 'SUHU',
                    value: room.currentData.temperature.toStringAsFixed(1),
                    unit: '°C',
                    status: Helpers.getTemperatureStatus(room.currentData.temperature),
                    color: Helpers.getTemperatureColor(room.currentData.temperature),
                  ),
                  _buildParameterCell(
                    label: 'LEMBAB',
                    value: room.currentData.humidity.round().toString(),
                    unit: '%',
                    status: Helpers.getHumidityStatus(room.currentData.humidity),
                    color: Helpers.getHumidityColor(room.currentData.humidity),
                  ),
                  _buildLastUpdateCell(room),
                ],
              ),

              const SizedBox(height: 12),

              // Footer - Data source
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  if (room.isIot)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sensors,
                            size: 12,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Device IoT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 12,
                            color: Colors.purple[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Simulasi',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.purple[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildParameterCell({
    required String label,
    required String value,
    required String unit,
    required String status,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Label
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
              ),
            ),

            const SizedBox(height: 4),

            // Value and Unit
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Status chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                status.length > 10 ? '${status.substring(0, 10)}...' : status,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

 Widget _buildLastUpdateCell(Room room) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Builder(
          builder: (context) {
            final updateInfo =
                Helpers.formatCompactLastUpdate(room.currentData.updatedAt);
            final label = updateInfo['label'] ?? '';
            final time = updateInfo['time'] ?? '';
            final topLabel = label == 'HARI INI' ? 'UPDATE' : label;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 4),
                Text(
                  topLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF212529),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );
          },
        ),
      ),
    );
  }