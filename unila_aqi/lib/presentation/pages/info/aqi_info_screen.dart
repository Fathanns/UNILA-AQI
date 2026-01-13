import 'package:flutter/material.dart';
import '../../../data/repositories/aqi_info_repository.dart';
import '../../../data/models/aqi_info.dart';
import '../../../core/constants/colors.dart';

class AQIInfoScreen extends StatefulWidget {
  const AQIInfoScreen({super.key});

  @override
  State<AQIInfoScreen> createState() => _AQIInfoScreenState();
}

class _AQIInfoScreenState extends State<AQIInfoScreen> {
  final AQIInfoRepository _repository = AQIInfoRepository();
  late Future<AQIInfo> _aqiInfoFuture;

  @override
  void initState() {
    super.initState();
    _aqiInfoFuture = _repository.getAQIInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Informasi AQI'),
        centerTitle: true,
        elevation: 0,
      ),
      body: FutureBuilder<AQIInfo>(
        future: _aqiInfoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final aqiInfo = snapshot.data!;

          return _buildContent(aqiInfo);
        },
      ),
    );
  }

  Widget _buildContent(AQIInfo aqiInfo) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(aqiInfo),
          const SizedBox(height: 24),

          // Parameters
          _buildSectionTitle('Parameter yang Dimonitor'),
          const SizedBox(height: 12),
          ...aqiInfo.parameters.map(_buildParameterCard).toList(),
          const SizedBox(height: 24),

          // AQI Categories
          _buildSectionTitle('Kategori Indeks Kualitas Udara (AQI)'),
          const SizedBox(height: 12),
          ...aqiInfo.categories.map(_buildCategoryCard).toList(),
          const SizedBox(height: 24),

          // Units Information
          _buildSectionTitle('Penjelasan Satuan'),
          const SizedBox(height: 12),
          ...aqiInfo.units.map(_buildUnitCard).toList(),
          const SizedBox(height: 24),

          // Additional Information
          _buildSectionTitle('Tips Kesehatan'),
          _buildHealthTips(),
          const SizedBox(height: 32),

          // Footer
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader(AQIInfo aqiInfo) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              aqiInfo.icon,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 16),
            Text(
              aqiInfo.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              aqiInfo.description,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildParameterCard(AQIParameter parameter) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  parameter.icon,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parameter.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${parameter.abbreviation} (${parameter.unit})',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              parameter.description,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('🏥 Dampak Kesehatan:', parameter.impact),
            _buildInfoRow('📊 Sumber Utama:', parameter.source),
            _buildInfoRow('✅ Rentang Aman:', parameter.safeRange),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(AQICategory category) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: category.color, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: category.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: category.color,
                  ),
                ),
                const Spacer(),
                Text(
                  '${category.min} - ${category.max}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              category.description,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            _buildInfoRow('👥 Efek Kesehatan:', category.healthEffect),
            _buildInfoRow('💡 Rekomendasi:', category.recommendation),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitCard(UnitInfo unit) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    unit.symbol,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  unit.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              unit.description,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Contoh: ${unit.example}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthTips() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTipItem(
              '🌬️ Ventilasi yang Baik',
              'Pastikan ruangan memiliki sirkulasi udara yang cukup untuk mengurangi akumulasi CO₂ dan polutan',
            ),
            const SizedBox(height: 12),
            _buildTipItem(
              '🌱 Tanaman Dalam Ruangan',
              'Beberapa tanaman seperti lidah mertua dan peace lily dapat membantu membersihkan udara',
            ),
            const SizedBox(height: 12),
            _buildTipItem(
              '🔄 Monitor Rutin',
              'Periksa kualitas udara secara teratur, terutama di ruangan dengan banyak aktivitas',
            ),
            const SizedBox(height: 12),
            _buildTipItem(
              '🏃 Aktivitas Fisik',
              'Hindari aktivitas fisik berat saat kualitas udara sedang atau tidak sehat',
            ),
            const SizedBox(height: 12),
            _buildTipItem(
              '🩺 Kelompok Sensitif',
              'Anak-anak, lansia, dan penderita asma lebih rentan terhadap efek polusi udara',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              title.substring(0, 3),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      
    );
  }
}