import 'dart:ui';

import 'package:unila_aqi/data/models/aqi_info.dart';

class AQIInfoRepository {
  Future<AQIInfo> getAQIInfo() async {
    return AQIInfo(
      title: 'Air Quality Index (AQI)',
      description: 'AQI adalah indeks yang digunakan untuk melaporkan kualitas udara harian. '
          'AQI memberitahu Anda seberapa bersih atau tercemar udara Anda, dan apa efek kesehatan '
          'yang mungkin menjadi perhatian Anda.',
      icon: '🌤️',
      parameters: _getParameters(),
      categories: _getCategories(),
      units: _getUnits(),
    );
  }

  List<AQIParameter> _getParameters() {
    return [
      AQIParameter(
        name: 'PM2.5',
        abbreviation: 'PM2.5',
        description: 'Partikel halus dengan diameter 2.5 mikrometer atau lebih kecil. '
            'Sangat kecil dan dapat menembus jauh ke dalam paru-paru dan sistem peredaran darah.',
        unit: 'μg/m³',
        impact: 'Gangguan pernafasan, penyakit jantung, kanker paru-paru',
        source: 'Asap kendaraan, industri, kebakaran hutan, pembakaran sampah',
        safeRange: '0 - 12 μg/m³',
        icon: '🏗️',
      ),
      AQIParameter(
        name: 'PM10',
        abbreviation: 'PM10',
        description: 'Partikel dengan diameter 10 mikrometer atau lebih kecil. '
            'Dapat terhirup dan masuk ke dalam sistem pernafasan.',
        unit: 'μg/m³',
        impact: 'Iritasi mata, hidung, tenggorokan, dan paru-paru',
        source: 'Debu jalanan, konstruksi, industri, serbuk sari',
        safeRange: '0 - 54 μg/m³',
        icon: '🏗️',
      ),
      AQIParameter(
        name: 'Karbon Dioksida',
        abbreviation: 'CO₂',
        description: 'Gas tidak berbau dan tidak berwarna yang dihasilkan dari pembakaran bahan bakar. '
            'Indikator utama ventilasi ruangan.',
        unit: 'ppm',
        impact: 'Sakit kepala, kelelahan, sulit konsentrasi, penurunan produktivitas',
        source: 'Pernafasan manusia, peralatan elektronik, mesin pembakaran',
        safeRange: '350 - 600 ppm',
        icon: '☁️',
      ),
      AQIParameter(
        name: 'Suhu',
        abbreviation: 'T',
        description: 'Ukuran panas atau dinginnya udara dalam ruangan. '
            'Suhu yang tepat meningkatkan kenyamanan dan produktivitas.',
        unit: '°C',
        impact: 'Ketidaknyamanan, dehidrasi, penurunan konsentrasi',
        source: 'Cuaca eksternal, peralatan elektronik, manusia',
        safeRange: '22 - 26 °C',
        icon: '🌡️',
      ),
      AQIParameter(
        name: 'Kelembaban',
        abbreviation: 'RH',
        description: 'Jumlah uap air di udara. '
            'Kelembaban yang tepat penting untuk kesehatan pernafasan dan kenyamanan.',
        unit: '%',
        impact: 'Pertumbuhan jamur, alergi, ketidaknyamanan pernafasan',
        source: 'Aktivitas manusia, cuaca, ventilasi',
        safeRange: '40 - 60 %',
        icon: '💧',
      ),
    ];
  }

  List<AQICategory> _getCategories() {
    return [
      AQICategory(
        name: 'Baik',
        description: 'Kualitas udara sangat baik, tidak ada risiko kesehatan',
        color: Color(0xFF00E400),
        min: 0,
        max: 50,
        healthEffect: 'Kualitas udara dianggap memuaskan, dan polusi udara menimbulkan sedikit atau tidak ada risiko',
        recommendation: 'Sangat baik untuk beraktivitas di luar ruangan',
      ),
      AQICategory(
        name: 'Sedang',
        description: 'Kualitas udara dapat diterima, risiko kecil untuk sebagian orang sensitif',
        color: Color(0xFFFFFF00),
        min: 51,
        max: 100,
        healthEffect: 'Orang dengan kondisi pernafasan mungkin merasakan efek ringan',
        recommendation: 'Batasi aktivitas fisik berat di luar ruangan',
      ),
      AQICategory(
        name: 'Tidak Sehat',
        description: 'Setiap orang mungkin mulai mengalami efek kesehatan',
        color: Color(0xFFFF7E00),
        min: 101,
        max: 150,
        healthEffect: 'Anggota kelompok sensitif mungkin mengalami efek kesehatan yang lebih serius',
        recommendation: 'Hindari aktivitas di luar ruangan yang terlalu lama',
      ),
      AQICategory(
        name: 'Sangat Tidak Sehat',
        description: 'Peringatan kesehatan darurat, seluruh populasi terpengaruh',
        color: Color(0xFFFF0000),
        min: 151,
        max: 200,
        healthEffect: 'Setiap orang mungkin mengalami efek kesehatan yang lebih serius',
        recommendation: 'Hindari semua aktivitas di luar ruangan',
      ),
      AQICategory(
        name: 'Berbahaya',
        description: 'Kondisi darurat kesehatan, seluruh populasi akan terpengaruh',
        color: Color(0xFF8F3F97),
        min: 201,
        max: 300,
        healthEffect: 'Peringatan kesehatan darurat, efek kesehatan pada seluruh populasi',
        recommendation: 'Tetap di dalam ruangan dengan ventilasi yang baik',
      ),
    ];
  }

  List<UnitInfo> _getUnits() {
    return [
      UnitInfo(
        symbol: 'μg/m³',
        name: 'Mikrogram per Meter Kubik',
        description: 'Mengukur konsentrasi partikel dalam udara. '
            '1 μg/m³ = 0.000001 gram partikel dalam 1 meter kubik udara.',
        example: 'PM2.5: 15 μg/m³ berarti ada 15 mikrogram partikel halus dalam 1 m³ udara',
      ),
      UnitInfo(
        symbol: 'ppm',
        name: 'Parts Per Million',
        description: 'Mengukur jumlah molekul gas dalam 1 juta molekul udara. '
            'Menggambarkan konsentrasi gas yang sangat kecil.',
        example: 'CO₂: 400 ppm berarti ada 400 molekul CO₂ dalam 1 juta molekul udara',
      ),
      UnitInfo(
        symbol: '°C',
        name: 'Derajat Celsius',
        description: 'Skala suhu yang digunakan secara internasional. '
            '0°C adalah titik beku air, 100°C adalah titik didih air.',
        example: 'Suhu ruangan ideal: 24°C',
      ),
      UnitInfo(
        symbol: '%',
        name: 'Persen',
        description: 'Mengukur kelembaban relatif udara. '
            '100% berarti udara jenuh dengan uap air.',
        example: 'Kelembaban ideal: 50%',
      ),
      UnitInfo(
        symbol: 'AQI',
        name: 'Air Quality Index',
        description: 'Indeks kualitas udara tanpa satuan. '
            'Menggambarkan kondisi kualitas udara secara keseluruhan.',
        example: 'AQI 75 = Kualitas udara sedang',
      ),
    ];
  }
}