import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:unila_aqi/core/constants/app_constants.dart';
import 'package:unila_aqi/core/services/storage_service.dart';
import 'package:unila_aqi/data/models/sensor_data.dart';

class HistoryRepository {
  final StorageService _storage = StorageService();
  
  Future<String?> _getToken() async {
    return _storage.getString('auth_token');
  }
  
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }
  
  // Get history data untuk grafik - REAL DATA
  Future<HistoryDataResponse> getHistoryData({
    required String roomId,
    required DateTime selectedDate,
    int interval = 30,
  }) async {
    try {
      final headers = await _getHeaders();
      
      // Format tanggal menjadi YYYY-MM-DD
      final formattedDate = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
      
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/sensor-data/$roomId/history?date=$formattedDate&interval=$interval'),
        headers: headers,
      );
      
      print('📊 History API Response: ${response.statusCode}');
      print('📊 History URL: ${AppConstants.apiBaseUrl}/sensor-data/$roomId/history?date=$formattedDate&interval=$interval');
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        
        if (jsonResponse['success'] == true) {
          final List<dynamic> data = jsonResponse['data'];
          final aggregated = jsonResponse['aggregated'] ?? false;
          
          // Konversi ke list SensorData
          final sensorData = data.map((json) => SensorData.fromJson(json)).toList();
          
          // Sort by timestamp
          sensorData.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          
          return HistoryDataResponse(
            success: true,
            data: sensorData,
            aggregated: aggregated,
            count: sensorData.length,
            startDate: jsonResponse['startDate'] != null 
                ? DateTime.parse(jsonResponse['startDate'])
                : selectedDate,
            endDate: jsonResponse['endDate'] != null
                ? DateTime.parse(jsonResponse['endDate'])
                : selectedDate.add(const Duration(days: 1)),
          );
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to fetch history data');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception('Failed to fetch history data: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ History Repository Error: $e');
      return HistoryDataResponse(
        success: false,
        data: [],
        error: e.toString(),
      );
    }
  }
  
  // Get 24 hours sensor data - REAL DATA
  Future<List<SensorData>> get24HoursSensorData(String roomId) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/sensor-data/$roomId'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        
        if (jsonResponse['success'] == true) {
          final List<dynamic> data = jsonResponse['data'];
          
          // Konversi ke list SensorData
          final sensorData = data.map((json) => SensorData.fromJson(json)).toList();
          
          // Sort by timestamp
          sensorData.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          
          return sensorData;
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to fetch sensor data');
        }
      } else {
        throw Exception('Failed to fetch sensor data: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching 24h sensor data: $e');
      return [];
    }
  }
  
  // Get available dates dengan data
  Future<List<DateTime>> getAvailableDates(String roomId) async {
    try {
      await _getHeaders();
      
      // Untuk sekarang, kita akan generate 7 hari terakhir
      // Di production, Anda mungkin ingin query database untuk tanggal yang punya data
      final now = DateTime.now();
      final dates = <DateTime>[];
      
      for (int i = 0; i < 7; i++) {
        dates.add(DateTime(now.year, now.month, now.day - i));
      }
      
      return dates;
    } catch (e) {
      print('Error getting available dates: $e');
      return [];
    }
  }
}

class HistoryDataResponse {
  final bool success;
  final List<SensorData> data;
  final bool aggregated;
  final int? count;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? error;
  
  HistoryDataResponse({
    required this.success,
    required this.data,
    this.aggregated = false,
    this.count,
    this.startDate,
    this.endDate,
    this.error,
  });
}