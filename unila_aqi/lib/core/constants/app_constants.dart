class AppConstants {
  // API Configuration
  static const String apiBaseUrl = 'http://10.0.2.2:5000/api'; // For Android emulator
  // static const String apiBaseUrl = 'http://localhost:5000/api'; // For iOS simulator
  static const String socketUrl = 'http://10.0.2.2:5000'; // WebSocket URL
  
  // App Information
  static const String appName = 'UNILA Air Quality Index';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Sistem Monitoring Kualitas Udara UNILA';
  
  // Time Intervals
  static const int autoRefreshInterval = 60; // seconds
  static const int socketReconnectInterval = 5000; // milliseconds
  
  // AQI Thresholds
  static const Map<String, dynamic> aqiThresholds = {
    'good': {'min': 0, 'max': 50, 'color': '#00E400'},
    'moderate': {'min': 51, 'max': 100, 'color': '#FFFF00'},
    'unhealthy': {'min': 101, 'max': 150, 'color': '#FF7E00'},
    'very_unhealthy': {'min': 151, 'max': 200, 'color': '#FF0000'},
    'hazardous': {'min': 201, 'max': 300, 'color': '#8F3F97'},
    'dangerous': {'min': 301, 'max': 500, 'color': '#7E0023'},
  };
  
  // Parameter Ranges
  static const Map<String, dynamic> paramRanges = {
    'pm25': {
      'good': {'min': 0, 'max': 12},
      'moderate': {'min': 12.1, 'max': 35.4},
      'unhealthy': {'min': 35.5, 'max': 55.4},
      'very_unhealthy': {'min': 55.5, 'max': 150.4},
      'hazardous': {'min': 150.5, 'max': 250.4},
      'dangerous': {'min': 250.5, 'max': 500},
    },
    'temperature': {'ideal': {'min': 22, 'max': 26}},
    'humidity': {'ideal': {'min': 40, 'max': 60}},
  };
  
  // Health Recommendations
  static const Map<String, String> healthRecommendations = {
    'good': 'Kualitas udara sangat baik. Dapat beraktivitas seperti biasa.',
    'moderate': 'Kualitas udara cukup baik. Kelompok sensitif mungkin terpengaruh.',
    'unhealthy': 'Kualitas udara tidak sehat. Kelompok sensitif harus mengurangi aktivitas luar.',
    'very_unhealthy': 'Kualitas udara sangat tidak sehat. Semua orang harus mengurangi aktivitas luar.',
    'hazardous': 'Kualitas udara berbahaya. Hindari aktivitas luar ruangan.',
    'dangerous': 'Kualitas udara sangat berbahaya. Tetap di dalam ruangan.',
  };
}