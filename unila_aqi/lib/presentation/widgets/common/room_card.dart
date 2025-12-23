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
    final timeAgo = Helpers.formatTimeAgo(room.currentData.updatedAt);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      room.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: aqiColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: aqiColor),
                    ),
                    child: Text(
                      'AQI: ${room.currentAQI}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: aqiColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // AQI Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: aqiColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  aqiLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Sensor Data Grid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSensorItem('PM2.5', '${room.currentData.pm25.toStringAsFixed(1)}', 
                      Helpers.getPM25Status(room.currentData.pm25), 
                      Helpers.getPM25Color(room.currentData.pm25)),
                  _buildSensorItem('PM10', '${room.currentData.pm10.toStringAsFixed(1)}', 
                      Helpers.getPM25Status(room.currentData.pm10), 
                      Helpers.getPM25Color(room.currentData.pm10)),
                  _buildSensorItem('CO₂', '${room.currentData.co2.round()}', 
                      Helpers.getCO2Status(room.currentData.co2), 
                      Helpers.getCO2Color(room.currentData.co2)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSensorItem('Suhu', '${room.currentData.temperature.toStringAsFixed(1)}°C', 
                      Helpers.getTemperatureStatus(room.currentData.temperature), 
                      Helpers.getTemperatureColor(room.currentData.temperature)),
                  _buildSensorItem('Kelembaban', '${room.currentData.humidity.round()}%', 
                      Helpers.getHumidityStatus(room.currentData.humidity), 
                      Helpers.getHumidityColor(room.currentData.humidity)),
                  Container(), // Empty for alignment
                ],
              ),
              const SizedBox(height: 16),
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    room.buildingName,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    'Update: $timeAgo',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              // Data Source Indicator
              if (room.isIot)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sensors, size: 12, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        'IoT Device',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSensorItem(String label, String value, String status, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}