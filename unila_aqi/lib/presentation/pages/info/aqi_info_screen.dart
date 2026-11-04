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
  AQIInfo? _aqiInfo;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final info = await _repository.getAQIInfo();
      if (!mounted) return;
      setState(() {
        _aqiInfo = info;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bantuan & Informasi'),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            const Text('Gagal memuat informasi', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final info = _aqiInfo!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildIntroBanner(),
        const SizedBox(height: 20),
        _ExpandableSection(
          emoji: '📖',
          title: 'Apa itu AQI/ISPU?',
          color: AppColors.primary,
          child: _buildWhatIsAQI(info),
        ),
        _ExpandableSection(
          emoji: '📊',
          title: 'Parameter yang Dimonitor',
          color: AppColors.primary,
          child: _buildParameters(info),
        ),
        _ExpandableSection(
          emoji: '🎨',
          title: 'Kategori Kualitas Udara',
          color: AppColors.primary,
          child: _buildCategories(info),
        ),
        _ExpandableSection(
          emoji: '📏',
          title: 'Penjelasan Satuan',
          color: AppColors.primary,
          child: _buildUnits(info),
        ),
        _ExpandableSection(
          emoji: '🏥',
          title: 'Dampak Kesehatan & Rekomendasi',
          color: AppColors.primary,
          child: _buildHealth(info),
        ),
        _ExpandableSection(
          emoji: '🔄',
          title: 'Cara Membaca Data di Aplikasi',
          color: AppColors.primary,
          child: _buildHowToRead(),
        ),
        _ExpandableSection(
          emoji: '❓',
          title: 'FAQ / Troubleshooting',
          color: AppColors.primary,
          child: _buildFAQ(),
        ),
        _ExpandableSection(
          emoji: 'ℹ️',
          title: 'Tentang Aplikasi',
          color: AppColors.primary,
          child: _buildAbout(),
        ),
      ],
    );
  }

  // ============================================================
  // INTRO BANNER
  // ============================================================
  Widget _buildIntroBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.help_outline_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pusat Bantuan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamily: 'Inter',
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Ketuk tiap bagian di bawah untuk membuka penjelasan.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white,
                    height: 1.4,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 1. APA ITU AQI/ISPU?
  // ============================================================
  Widget _buildWhatIsAQI(AQIInfo info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _paragraph(
          'Air Quality Index (AQI) atau ISPU (Indeks Standar Pencemar Udara) '
          'adalah angka tanpa satuan yang menunjukkan seberapa bersih atau '
          'tercemar udara pada suatu lokasi, serta dampak kesehatannya.',
        ),
        const SizedBox(height: 12),
        _paragraph(
          'Aplikasi ini mengikuti standar PP No. 22 Tahun 2021 tentang '
          'Penyelenggaraan Perlindungan dan Pengelolaan Lingkungan Hidup. '
          'Nilai ISPU dikelompokkan menjadi 5 kategori: Baik, Sedang, '
          'Tidak Sehat, Sangat Tidak Sehat, dan Berbahaya.',
        ),
        const SizedBox(height: 12),
        _paragraph(
          'ISPU dipengaruhi oleh konsentrasi partikel polusi di udara, yaitu PM2.5, PM10, '
          'serta gas CO, SO2, O3, dan NO2. Semakin tinggi konsentrasi parameter tersebut, '
          'semakin tinggi nilai ISPU, dan semakin besar risiko kesehatan bagi penghuni ruangan.',
        ),
        const SizedBox(height: 12),
        _paragraph(
          'Setiap parameter (PM2.5, PM10, CO, SO2, O3, dan NO2) dihitung '
          'terpisah menggunakan interpolasi linear terhadap tabel breakpoint '
          'PP 22/2021. Nilai ISPU ruangan adalah nilai MAX dari keenam parameter.',
        ),
        const SizedBox(height: 16),
        _subheading('Tabel Breakpoint PM2.5'),
        const SizedBox(height: 16),
        _breakpointTable(
          headers: const ['ISPU Bawah', 'ISPU Atas', 'Kons. Bawah', 'Kons. Atas'],
          rows: const [
            ['0', '50', '0', '55'],
            ['51', '100', '56', '150'],
            ['101', '200', '151', '250'],
            ['201', '300', '251', '350'],
            ['301', '500', '351', '500'],
          ],
          unit: 'μg/m³',
        ),
        const SizedBox(height: 16),
        _subheading('Tabel Breakpoint PM10'),
        const SizedBox(height: 16),
        _breakpointTable(
          headers: const ['ISPU Bawah', 'ISPU Atas', 'Kons. Bawah', 'Kons. Atas'],
          rows: const [
            ['0', '50', '0', '50'],
            ['51', '100', '51', '150'],
            ['101', '200', '151', '350'],
            ['201', '300', '351', '420'],
            ['301', '500', '421', '500'],
          ],
          unit: 'μg/m³',
        ),
        const SizedBox(height: 16),
        _subheading('Tabel Breakpoint CO'),
        const SizedBox(height: 16),
        _breakpointTable(
          headers: const ['ISPU Bawah', 'ISPU Atas', 'Kons. Bawah', 'Kons. Atas'],
          rows: const [
            ['0', '50', '0', '4.000'],
            ['51', '100', '4.001', '8.000'],
            ['101', '200', '8.001', '15.000'],
            ['201', '300', '15.001', '30.000'],
            ['301', '500', '30.001', '45.000'],
          ],
          unit: 'μg/m³',
        ),
        const SizedBox(height: 16),
        _subheading('Tabel Breakpoint SO2'),
        const SizedBox(height: 16),
        _breakpointTable(
          headers: const ['ISPU Bawah', 'ISPU Atas', 'Kons. Bawah', 'Kons. Atas'],
          rows: const [
            ['0', '50', '0', '80'],
            ['51', '100', '81', '365'],
            ['101', '200', '366', '800'],
            ['201', '300', '801', '1.600'],
            ['301', '500', '1.601', '3.000'],
          ],
          unit: 'μg/m³',
        ),
        const SizedBox(height: 16),
        _subheading('Tabel Breakpoint O3'),
        const SizedBox(height: 16),
        _breakpointTable(
          headers: const ['ISPU Bawah', 'ISPU Atas', 'Kons. Bawah', 'Kons. Atas'],
          rows: const [
            ['0', '50', '0', '120'],
            ['51', '100', '121', '235'],
            ['101', '200', '236', '400'],
            ['201', '300', '401', '800'],
            ['301', '500', '801', '1.000'],
          ],
          unit: 'μg/m³',
        ),
        const SizedBox(height: 16),
        _subheading('Tabel Breakpoint NO2'),
        const SizedBox(height: 16),
        _breakpointTable(
          headers: const ['ISPU Bawah', 'ISPU Atas', 'Kons. Bawah', 'Kons. Atas'],
          rows: const [
            ['0', '50', '0', '80'],
            ['51', '100', '81', '200'],
            ['101', '200', '201', '1.130'],
            ['201', '300', '1.131', '2.260'],
            ['301', '500', '2.261', '3.000'],
          ],
          unit: 'μg/m³',
        ),
        const SizedBox(height: 16),
        _subheading('Rumus ISPU'),
        const SizedBox(height: 16),
        _codeBox(
          'ISPU = ((ISPU_high − ISPU_low) / (C_high − C_low)) × (C − C_low) + ISPU_low'
        ),
        const SizedBox(height: 12),
        _paragraph(
          'Keterangan:',
        ),
        _bulletList([
          'C = konsentrasi partikel (μg/m³)',
          'C_low =  batas bawah konsentrasi pada segmen',
          'C_high = batas atas konsentrasi pada segmen',
          'ISPU_low = batas bawah nilai ISPU pada segmen',
          'ISPU_high = batas atas nilai ISPU pada segmen',
        ]),
        const SizedBox(height: 16),
        _subheading('Contoh Perhitungan'),
        const SizedBox(height: 16),
        _paragraph(
          'Diketahui PM2.5 ruangan = 100 μg/m³. Nilai ini berada pada '
          'segmen kedua, yaitu:',
        ),

        _bulletList([
          'C_low = 56',
          'C_high = 150',
          'C_high = batas atas konsentrasi pada segmen',
          'ISPU_low = 51',
          'ISPU_high = 100',
        ]),
        const SizedBox(height: 12),
        _codeBox(
          'ISPU = ((100 − 51) / (150 − 56)) × (100 − 56) + 51\n'
          '     = (49 / 94) × 44 + 51\n'
          '     = 22.94 + 51\n'
          '     ≈ 74',
        ),
        const SizedBox(height: 12),
         _paragraph(
          'Diketahui PM10 ruangan = 30 μg/m³. Nilai ini berada pada '
          'segmen pertama, yaitu:',
        ),
        _bulletList([
          'C_low = 0',
          'C_high = 50',
          'ISPU_low = 0',
          'ISPU_high = 50',
        ]),
        const SizedBox(height: 12),
        _codeBox(
          'ISPU = ((30 − 0) / (50 − 0)) × (50 − 0) + 0\n'
          '     = (30 / 50) × 50\n'
          '     = 30',
        ),
        const SizedBox(height: 12), 

        _paragraph(
          'Nilai ISPU dalam ruangan diambil dari partikel yang lebih dominan, yaitu PM2.5 yang memiliki nilai lebih tinggi dari PM10.\n'
          'Maka, ISPU ruangan tersbeut adalah 74.',
        ),
      ],
    );
  }

  // ============================================================
  // 2. PARAMETER YANG DIMONITOR (konteks dalam ruangan)
  // ============================================================
  Widget _buildParameters(AQIInfo info) {
    final indoorParams = <AQIParameter>[
      AQIParameter(
        name: 'PM2.5',
        abbreviation: 'PM2.5',
        description:
            'Partikel halus berukuran ≤ 2.5 mikrometer yang melayang di udara '
            'ruangan. Di dalam ruangan, partikel ini berasal dari asap rokok, '
            'uap memasak, printer, lilin, dan debu halus yang tersuspensi. '
            'Ukurannya sangat kecil sehingga dapat menembus jauh ke dalam '
            'paru-paru dan masuk ke sistem peredaran darah.',
        unit: 'μg/m³',
        impact:
            'Iritasi saluran pernapasan, memperburuk asma, risiko penyakit '
            'kardiovaskular, penurunan fungsi paru-paru.',
        source:
            'Asap rokok, uap memasak, printer, lilin, debu furnitur, VOC '
            'dari cat/furnitur baru, partikel dari ventilasi.',
        safeRange: '0 – 55 μg/m³ (ISPU ≤ 50)',
        icon: '🏗️',
      ),
      AQIParameter(
        name: 'PM10',
        abbreviation: 'PM10',
        description:
            'Partikel berukuran ≤ 10 mikrometer yang tersuspensi di udara '
            'ruangan. Di dalam ruangan, partikel ini berasal dari debu lantai, '
            'serat kain/sofa, spora jamur, dan partikel dari luar yang masuk '
            'melalui pintu/jendela/ventilasi.',
        unit: 'μg/m³',
        impact:
            'Iritasi mata, hidung, tenggorokan, dan saluran pernapasan bagian '
            'atas; memperburuk alergi debu.',
        source:
            'Debu lantai/meja, serat kain & karpet, spora jamur, partikel '
            'masuk dari ventilasi.',
        safeRange: '0 – 50 μg/m³ (ISPU ≤ 50)',
        icon: '🏗️',
      ),
      AQIParameter(
        name: 'Karbon Monoksida',
        abbreviation: 'CO',
        description:
            'Gas tidak berbau dan tidak berwarna hasil pembakaran tidak sempurna. '
            'Di dalam ruangan, gas ini bisa berasal dari kompor, pemanas, atau masuknya asap kendaraan dari luar.',
        unit: 'µg/m³',
        impact:
            'Sakit kepala, pusing, mual, memperburuk kondisi jantung.',
        source:
            'Kompor gas, asap kendaraan masuk, sistem ventilasi yang buruk.',
        safeRange: '0 – 4.000 µg/m³ (ISPU ≤ 50)',
        icon: '☁️',
      ),
      AQIParameter(
        name: 'Sulfur Dioksida',
        abbreviation: 'SO2',
        description:
            'Gas tidak berwarna dengan bau menyengat yang dihasilkan dari '
            'pembakaran bahan bakar fosil yang mengandung sulfur (batu bara, '
            'minyak). Di dalam ruangan, SO2 dapat berasal dari asap kendaraan '
            'yang masuk melalui ventilasi, kompor gas, atau pembakaran lilin.',
        unit: 'μg/m³',
        impact:
            'Iritasi saluran pernapasan, memperburuk asma dan bronkitis, '
            'iritasi mata dan tenggorokan, penurunan fungsi paru-paru.',
        source:
            'Pembakaran bahan bakar fosil, asap kendaraan, kompor gas, '
            'pembakaran lilin, ventilasi dari luar.',
        safeRange: '0 – 80 μg/m³ (ISPU ≤ 50)',
        icon: '🏭',
      ),
      AQIParameter(
        name: 'Ozon',
        abbreviation: 'O3',
        description:
            'Gas yang terbentuk dari reaksi fotokimia antara nitrogen oksida '
            '(NOx) dan senyawa organik volatil (VOC) dengan bantuan sinar '
            'matahari. Di dalam ruangan, O3 dapat berasal dari peralatan '
            'elektronik seperti printer, mesin fotokopi, dan air purifier '
            'yang menghasilkan ozon, atau masuk dari luar.',
        unit: 'μg/m³',
        impact:
            'Iritasi saluran pernapasan, penurunan fungsi paru-paru, '
            'memperburuk asma, nyeri dada saat bernapas dalam.',
        source:
            'Reaksi fotokimia di luar ruangan, peralatan elektronik '
            '(printer, fotokopi), air purifier tipe ozon, ventilasi dari luar.',
        safeRange: '0 – 120 μg/m³ (ISPU ≤ 50)',
        icon: '⚡',
      ),
      AQIParameter(
        name: 'Nitrogen Dioksida',
        abbreviation: 'NO2',
        description:
            'Gas cokelat kemerahan dengan bau menyengat yang dihasilkan dari '
            'pembakaran pada suhu tinggi (mesin kendaraan, pembangkit listrik). '
            'Di dalam ruangan, NO2 dapat berasal dari kompor gas, pemanas '
            'ruangan, asap rokok, dan asap kendaraan yang masuk melalui '
            'ventilasi.',
        unit: 'μg/m³',
        impact:
            'Iritasi saluran pernapasan, memperburuk asma dan infeksi '
            'pernapasan, penurunan fungsi paru-paru pada paparan jangka panjang.',
        source:
            'Kompor gas, pemanas ruangan berbahan bakar, asap rokok, '
            'asap kendaraan, sistem ventilasi yang buruk.',
        safeRange: '0 – 80 μg/m³ (ISPU ≤ 50)',
        icon: '🚗',
      ),
      AQIParameter(
        name: 'Suhu',
        abbreviation: 'T',
        description:
            'Ukuran panas atau dinginnya udara dalam ruangan. Suhu yang tepat '
            'meningkatkan kenyamanan termal, konsentrasi, dan produktivitas '
            'saat belajar atau bekerja.',
        unit: '°C',
        impact:
            'Ketidaknyamanan, dehidrasi, penurunan konsentrasi, gangguan tidur.',
        source:
            'Cuaca eksternal, peralatan elektronik, jumlah orang dalam ruangan, '
            'AC/kipas/pemanas.',
        safeRange: '24 – 27 °C',
        icon: '🌡️',
      ),
      AQIParameter(
        name: 'Kelembaban',
        abbreviation: 'RH',
        description:
            'Jumlah uap air di udara ruangan. Kelembaban yang tepat penting '
            'untuk kesehatan pernapasan dan mencegah pertumbuhan jamur di '
            'dinding, plafon, atau unit AC.',
        unit: '%',
        impact:
            'Pertumbuhan jamur & tungau, alergi, iritasi pernapasan, '
            'ketidaknyamanan.',
        source:
            'Aktivitas manusia (bernafas, berkeringat), AC, ventilasi, cuaca.',
        safeRange: '40 – 60 %',
        icon: '💧',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _paragraph(
          'Aplikasi memantau 8 parameter lingkungan di dalam ruangan. '
          'Enam parameter polutan (PM2.5, PM10, CO, SO2, O3, dan NO2) '
          'menentukan nilai AQI/ISPU ruangan (diambil nilai MAX dari '
          'keenam parameter), sedangkan dua parameter lainnya (suhu dan '
          'kelembaban) memberi konteks kenyamanan & ventilasi ruangan.',
        ),
        const SizedBox(height: 16),
        ...indoorParams.map(_buildParameterCard),
      ],
    );
  }

  Widget _buildParameterCard(AQIParameter p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(p.icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                      ),
                    ),
                    Text(
                      '${p.abbreviation} • ${p.unit}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            p.description,
            textAlign: TextAlign.justify,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 10),
          _infoRow('🏥 Dampak', p.impact),
          _infoRow('📊 Sumber', p.source),
          _infoRow('✅ Aman', p.safeRange),
        ],
      ),
    );
  }

  // ============================================================
  // 3. KATEGORI KUALITAS UDARA
  // ============================================================
  Widget _buildCategories(AQIInfo info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _paragraph(
          'Kategori kualitas udara menggunakan indikator warna menentukan cara membaca angka AQI. '
        ),
        const SizedBox(height: 16),
        _subheading('Kategori AQI/ISPU'),
        const SizedBox(height: 8),
        ...info.categories.map(_buildCategoryRow),
        const SizedBox(height: 20),
        _subheading('Kategori per Parameter (dengan legenda warna)'),
        const SizedBox(height: 8),
        _parameterCategoryTable(
          title: 'PM2.5 (μg/m³)',
          rows: const [
            {'range': '0 – 55', 'label': 'Baik', 'color': AppColors.aqiGood},
            {'range': '56 – 150', 'label': 'Sedang', 'color': AppColors.aqiModerate},
            {'range': '151 – 250', 'label': 'Tidak Sehat', 'color': AppColors.aqiUnhealthySensitive},
            {'range': '251 – 350', 'label': 'Sangat Tidak Sehat', 'color': AppColors.aqiUnhealthy},
            {'range': '351 – 500', 'label': 'Berbahaya', 'color': AppColors.aqiHazardous},
          ],
        ),
        _parameterCategoryTable(
          title: 'PM10 (μg/m³)',
          rows: const [
            {'range': '0 – 50', 'label': 'Baik', 'color': AppColors.aqiGood},
            {'range': '51 – 150', 'label': 'Sedang', 'color': AppColors.aqiModerate},
            {'range': '151 – 350', 'label': 'Tidak Sehat', 'color': AppColors.aqiUnhealthySensitive},
            {'range': '351 – 420', 'label': 'Sangat Tidak Sehat', 'color': AppColors.aqiUnhealthy},
            {'range': '421 – 500', 'label': 'Berbahaya', 'color': AppColors.aqiHazardous},
          ],
        ),
        _parameterCategoryTable(
          title: 'CO (µg/m³)', 
          rows: const [
            {'range': '0 – 4.000', 'label': 'Baik', 'color': AppColors.aqiGood},
            {'range': '4.001 – 8.000', 'label': 'Sedang', 'color': AppColors.aqiModerate},
            {'range': '8.001 – 15.000', 'label': 'Tidak Sehat', 'color': AppColors.aqiUnhealthySensitive},
            {'range': '15.001 – 30.000', 'label': 'Sangat Tidak Sehat', 'color': AppColors.aqiUnhealthy},
            {'range': '> 30.000', 'label': 'Berbahaya', 'color': AppColors.aqiHazardous},
          ],
        ),
        _parameterCategoryTable(
          title: 'SO2 (μg/m³)',
          rows: const [
            {'range': '0 – 80', 'label': 'Baik', 'color': AppColors.aqiGood},
            {'range': '81 – 365', 'label': 'Sedang', 'color': AppColors.aqiModerate},
            {'range': '366 – 800', 'label': 'Tidak Sehat', 'color': AppColors.aqiUnhealthySensitive},
            {'range': '801 – 1.600', 'label': 'Sangat Tidak Sehat', 'color': AppColors.aqiUnhealthy},
            {'range': '1.601 – 3.000', 'label': 'Berbahaya', 'color': AppColors.aqiHazardous},
          ],
        ),
        _parameterCategoryTable(
          title: 'O3 (μg/m³)',
          rows: const [
            {'range': '0 – 120', 'label': 'Baik', 'color': AppColors.aqiGood},
            {'range': '121 – 235', 'label': 'Sedang', 'color': AppColors.aqiModerate},
            {'range': '236 – 400', 'label': 'Tidak Sehat', 'color': AppColors.aqiUnhealthySensitive},
            {'range': '401 – 800', 'label': 'Sangat Tidak Sehat', 'color': AppColors.aqiUnhealthy},
            {'range': '801 – 1.000', 'label': 'Berbahaya', 'color': AppColors.aqiHazardous},
          ],
        ),
        _parameterCategoryTable(
          title: 'NO2 (μg/m³)',
          rows: const [
            {'range': '0 – 80', 'label': 'Baik', 'color': AppColors.aqiGood},
            {'range': '81 – 200', 'label': 'Sedang', 'color': AppColors.aqiModerate},
            {'range': '201 – 1.130', 'label': 'Tidak Sehat', 'color': AppColors.aqiUnhealthySensitive},
            {'range': '1.131 – 2.260', 'label': 'Sangat Tidak Sehat', 'color': AppColors.aqiUnhealthy},
            {'range': '2.261 – 3.000', 'label': 'Berbahaya', 'color': AppColors.aqiHazardous},
          ],
        ),
        _parameterCategoryTable(
          title: 'Suhu (°C)',
          rows: const [
            {'range': '< 24', 'label': 'Dingin', 'color': Colors.blue},
            {'range': '24 – 27', 'label': 'Ideal', 'color': AppColors.aqiGood},
            {'range': '28 – 30', 'label': 'Hangat', 'color': AppColors.warning},
            {'range': '> 30', 'label': 'Panas', 'color': AppColors.error},
          ],
        ),
        _parameterCategoryTable(
          title: 'Kelembaban (%)',
          rows: const [
            {'range': '< 40', 'label': 'Kering', 'color': AppColors.aqiUnhealthySensitive},
            {'range': '40 – 60', 'label': 'Ideal', 'color': AppColors.aqiGood},
            {'range': '61 – 70', 'label': 'Lembab', 'color': AppColors.aqiModerate},
            {'range': '> 70', 'label': 'Tidak Nyaman', 'color': AppColors.aqiUnhealthy},
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryRow(AQICategory c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: c.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              c.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: c.color,
                fontFamily: 'Inter',
              ),
            ),
          ),
          Text(
            '${c.min} – ${c.max}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _parameterCategoryTable({
    required String title,
    required List<Map<String, dynamic>> rows,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          ...rows.map((r) {
            final color = r['color'] as Color;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r['range'] as String,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  Text(
                    r['label'] as String,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: color,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ============================================================
  // 4. PENJELASAN SATUAN
  // ============================================================
  Widget _buildUnits(AQIInfo info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _paragraph(
          'Setiap parameter menggunakan satuan yang berbeda. Berikut penjelasan '
          'singkat tiap satuan agar Anda bisa membaca data dengan tepat.',
        ),
        const SizedBox(height: 16),
        ...info.units.map(
          (u) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        u.symbol,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        u.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  u.description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textSecondary,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Contoh: ${u.example}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textHint,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 5. DAMPAK KESEHATAN & REKOMENDASI
  // ============================================================
  Widget _buildHealth(AQIInfo info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _paragraph(
          'Semakin tinggi nilai AQI/ISPU, semakin besar risiko kesehatan bagi '
          'seluruh penghuni ruangan, terutama kelompok sensitif (anak-anak, '
          'lansia, ibu hamil, dan penderita gangguan pernapasan).',
        ),
        const SizedBox(height: 16),
        _subheading('Dampak AQI/ISPU pada Ruangan'),
        const SizedBox(height: 8),
        ...info.categories.map(
          (c) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.color.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration:
                          BoxDecoration(color: c.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      c.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.color,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${c.min}–${c.max})',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _infoRow('👥 Efek', c.healthEffect),
                _infoRow('💡 Saran', _indoorAqiRecommendation(c.min, c.max)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _subheading('Rekomendasi per Parameter'),
        const SizedBox(height: 8),
        _buildParameterRecommendationCard(
          title: 'PM2.5 (μg/m³)',
          rows: const [
            {
              'range': '0 – 55',
              'color': AppColors.aqiGood,
              'rec': 'Aman untuk perkuliahan. Jaga kebersihan lantai dan meja.',
            },
            {
              'range': '56 – 150',
              'color': AppColors.aqiModerate,
              'rec':
                  'Nyalakan air purifier bila ada. Hindari aktivitas berdebu '
                      '(menyapu kering, buka jendela saat lalu lintas padat).',
            },
            {
              'range': '151 – 250',
              'color': AppColors.aqiUnhealthySensitive,
              'rec':
                  'Wajib nyalakan air purifier. Masker disarankan. Tutup jendela. '
                      'Bersihkan filter AC/purifier.',
            },
            {
              'range': '251 – 350',
              'color': AppColors.aqiUnhealthy,
              'rec':
                  'Masker wajib (surgical/N95). Air purifier kecepatan maksimum. '
                      'Pertimbangkan relokasi kelas atau daring.',
            },
            {
              'range': '351 – 500',
              'color': AppColors.aqiHazardous,
              'rec':
                  'Tidak ada aktivitas tatap muka. Evakuasi ruangan bila perlu. '
                      'Air purifier 24 jam. Investigasi sumber polusi.',
            },
          ],
        ),
        _buildParameterRecommendationCard(
          title: 'PM10 (μg/m³)',
          rows: const [
            {
              'range': '0 – 50',
              'color': AppColors.aqiGood,
              'rec': 'Aman. Jaga kebersihan lantai dan meja.',
            },
            {
              'range': '51 – 150',
              'color': AppColors.aqiModerate,
              'rec':
                  'Bersihkan kelas secara basah (pel basah) sebelum perkuliahan. '
                      'Hindari menyapu kering. Pastikan filter AC bersih.',
            },
            {
              'range': '151 – 350',
              'color': AppColors.aqiUnhealthySensitive,
              'rec':
                  'Masker disarankan. Nyalakan air purifier. Tutup jendela. '
                      'Pel basah lebih sering.',
            },
            {
              'range': '351 – 420',
              'color': AppColors.aqiUnhealthy,
              'rec':
                  'Masker wajib. Air purifier kecepatan maksimum. Batasi '
                      'aktivitas fisik. Pertimbangkan daring.',
            },
            {
              'range': '421 – 500',
              'color': AppColors.aqiHazardous,
              'rec':
                  'Tidak ada aktivitas tatap muka. Evakuasi. Investigasi sumber '
                      'debu (renovasi/jalan raya/gudang).',
            },
          ],
        ),
        _buildParameterRecommendationCard(
          title: 'CO (µg/m³)', 
          rows: const [
            {
              'range': '0 – 4.000',
              'color': AppColors.aqiGood,
              'rec': 'Ventilasi sangat baik. Aman untuk perkuliahan normal.',
            },
            {
              'range': '4.001 – 8.000',
              'color': AppColors.aqiModerate,
              'rec':
                  'Pastikan ventilasi mekanis/AC fresh air berjalan. Bila '
                      'memungkinkan buka pintu/jendela sesaat.',
            },
            {
              'range': '8.001 – 15.000',
              'color': AppColors.aqiUnhealthySensitive,
              'rec':
                  'Buka jendela/pintu untuk ventilasi silang. Nyalakan exhaust '
                      'fan. Kurangi kapasitas mahasiswa di ruangan.',
            },
            {
              'range': '15.001 – 30.000',
              'color': AppColors.aqiUnhealthy,
              'rec':
                  'Ventilasi darurat — buka semua akses udara, exhaust maksimum. '
                      'Pertimbangkan mengosongkan ruangan sementara.',
            },
            {
              'range': '> 30.000',
              'color': AppColors.aqiHazardous,
              'rec':
                  'Evakuasi ruangan. Investigasi segera (sistem HVAC, '
                      'kebocoran, ruangan tertutup terlalu lama).',
            },
          ],
        ),
        _buildParameterRecommendationCard(
          title: 'SO2 (μg/m³)',
          rows: const [
            {
              'range': '0 – 80',
              'color': AppColors.aqiGood,
              'rec': 'Aman untuk perkuliahan normal.',
            },
            {
              'range': '81 – 365',
              'color': AppColors.aqiModerate,
              'rec':
                  'Pastikan ventilasi ruangan baik. Hindari sumber pembakaran '
                      'di sekitar ruangan (kompor gas, lilin, asap kendaraan).',
            },
            {
              'range': '366 – 800',
              'color': AppColors.aqiUnhealthySensitive,
              'rec':
                  'Nyalakan ventilasi/exhaust. Masker disarankan. Kurangi '
                      'aktivitas fisik berat dan tutup jendela bila luar berasap.',
            },
            {
              'range': '801 – 1.600',
              'color': AppColors.aqiUnhealthy,
              'rec':
                  'Masker wajib. Ventilasi maksimum. Pertimbangkan relokasi '
                      'kelas atau alihkan ke daring sampai kadar SO2 turun.',
            },
            {
              'range': '1.601 – 3.000',
              'color': AppColors.aqiHazardous,
              'rec':
                  'Evakuasi ruangan. Investigasi sumber gas sulfur segera '
                      '(kompor, pemanas, kebocoran gas, ventilasi luar).',
            },
          ],
        ),
        _buildParameterRecommendationCard(
          title: 'O3 (μg/m³)',
          rows: const [
            {
              'range': '0 – 120',
              'color': AppColors.aqiGood,
              'rec': 'Aman untuk perkuliahan normal.',
            },
            {
              'range': '121 – 235',
              'color': AppColors.aqiModerate,
              'rec':
                  'Kelompok sensitif (asma, lansia) sebaiknya mengurangi '
                      'aktivitas fisik berat. Matikan printer/fotokopi yang tidak '
                      'terpakai bila memungkinkan.',
            },
            {
              'range': '236 – 400',
              'color': AppColors.aqiUnhealthySensitive,
              'rec':
                  'Kurangi aktivitas fisik berat. Masker disarankan. Nyalakan '
                      'air purifier bila ada. Batasi penggunaan peralatan '
                      'elektronik yang menghasilkan ozon.',
            },
            {
              'range': '401 – 800',
              'color': AppColors.aqiUnhealthy,
              'rec':
                  'Masker wajib. Batasi durasi tatap muka. Pertimbangkan '
                      'daring. Matikan sumber ozon (printer, fotokopi, air '
                      'purifier tipe ozon).',
            },
            {
              'range': '801 – 1.000',
              'color': AppColors.aqiHazardous,
              'rec':
                  'Tidak ada aktivitas tatap muka. Evakuasi ruangan. '
                      'Investigasi sumber ozon segera (peralatan elektronik, '
                      'ventilasi dari luar).',
            },
          ],
        ),
        _buildParameterRecommendationCard(
          title: 'NO2 (μg/m³)',
          rows: const [
            {
              'range': '0 – 80',
              'color': AppColors.aqiGood,
              'rec': 'Aman untuk perkuliahan normal.',
            },
            {
              'range': '81 – 200',
              'color': AppColors.aqiModerate,
              'rec':
                  'Pastikan ventilasi baik. Hindari sumber pembakaran di dalam '
                      'ruangan (kompor gas, pemanas, asap rokok).',
            },
            {
              'range': '201 – 1.130',
              'color': AppColors.aqiUnhealthySensitive,
              'rec':
                  'Nyalakan exhaust/ventilasi. Masker disarankan. Kurangi '
                      'kapasitas ruangan dan hindari penggunaan kompor gas '
                      'di dalam ruangan.',
            },
            {
              'range': '1.131 – 2.260',
              'color': AppColors.aqiUnhealthy,
              'rec':
                  'Masker wajib. Ventilasi darurat — buka semua akses udara, '
                      'exhaust maksimum. Pertimbangkan mengosongkan ruangan '
                      'sementara.',
            },
            {
              'range': '2.261 – 3.000',
              'color': AppColors.aqiHazardous,
              'rec':
                  'Evakuasi ruangan. Investigasi kebocoran gas / sistem HVAC / '
                      'sumber pembakaran dalam ruangan segera. Hubungi teknisi.',
            },
          ],
        ),
        _buildParameterRecommendationCard(
          title: 'Suhu (°C)',
          rows: const [
            {
              'range': '< 24',
              'color': Colors.blue,
              'rec':
                  'Nyalakan pemanas ruangan bila tersedia. Pakai pakaian hangat. '
                      'Hindari duduk dekat AC/ventilasi dingin.',
            },
            {
              'range': '24 – 27',
              'color': AppColors.aqiGood,
              'rec': 'Kondisi optimal untuk belajar. Tidak perlu tindakan.',
            },
            {
              'range': '28 – 30',
              'color': AppColors.warning,
              'rec':
                  'Nyalakan AC atau kipas. Pastikan sirkulasi udara baik. '
                      'Sediakan air minum.',
            },
            {
              'range': '> 30',
              'color': AppColors.error,
              'rec':
                  'AC/kipas wajib. Buka ventilasi bila AC tidak tersedia. '
                      'Sediakan air minum. Pertimbangkan relokasi ke ruangan '
                      'ber-AC.',
            },
          ],
        ),
        _buildParameterRecommendationCard(
          title: 'Kelembaban (%)',
          rows: const [
            {
              'range': '< 40',
              'color': AppColors.aqiUnhealthySensitive,
              'rec':
                  'Gunakan humidifier. Sediakan air minum. Hindari AC terlalu '
                      'dingin yang mengeringkan udara.',
            },
            {
              'range': '40 – 60',
              'color': AppColors.aqiGood,
              'rec': 'Kondisi optimal. Tidak perlu tindakan.',
            },
            {
              'range': '61 – 70',
              'color': AppColors.aqiModerate,
              'rec':
                  'Nyalakan dehumidifier atau AC mode dry. Pastikan ventilasi '
                      'baik. Waspada jamur pada dinding/AC.',
            },
            {
              'range': '> 70',
              'color': AppColors.aqiUnhealthy,
              'rec':
                  'Dehumidifier wajib. Tingkatkan ventilasi. Periksa kebocoran/'
                      'kelembaban dinding. Risiko jamur & tungau meningkat.',
            },
          ],
        ),
      ],
    );
  }

  String _indoorAqiRecommendation(int min, int max) {
    if (max <= 50) {
      return 'Aman untuk perkuliahan normal dengan durasi berapa pun. '
          'Tidak perlu tindakan khusus.';
    }
    if (max <= 100) {
      return 'Perkuliahan tatap muka tetap aman. Pastikan ruangan bebas debu '
          'berlebih. Kelompok sensitif sebaiknya tidak duduk dekat jendela.';
    }
    if (max <= 200) {
      return 'Kurangi aktivitas fisik berat di ruangan. Nyalakan air purifier '
          'bila tersedia. Masker disarankan untuk mahasiswa dengan riwayat '
          'pernapasan.';
    }
    if (max <= 300) {
      return 'Wajib memakai masker di dalam ruangan. Nyalakan air purifier '
          'kecepatan maksimum. Batasi durasi tatap muka.';
    }
    return 'Tidak ada aktivitas akademik tatap muka. Alihkan ke daring. '
        'Tim gedung pantau AQI setiap jam.';
  }

  Widget _buildParameterRecommendationCard({
    required String title,
    required List<Map<String, dynamic>> rows,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          ...rows.map((r) {
            final color = r['color'] as Color;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r['range'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          r['rec'] as String,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.textSecondary,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ============================================================
  // 6. CARA MEMBACA DATA DI APLIKASI
  // ============================================================
  Widget _buildHowToRead() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _paragraph(
          'Agar data di dashboard dan detail ruangan tidak membingungkan, '
          'berikut panduan membaca tiap elemen UI.',
        ),
        const SizedBox(height: 16),
        _miniHeading('Struktur Dashboard'),
        const SizedBox(height: 6),
        _paragraph(
          'Halaman dashboard tersusun dari card ruangan yang disusun di dalam gedungnya masing-masing. '
          'setiap card ruangan menampilkan informasi berupa indeks kualitas udara, parameter lingkungan, dan waktu update terakhir. '
        ),
         const SizedBox(height: 14),
        _miniHeading('Filter, Pencarian & Urutan'),
        const SizedBox(height: 6),
        _paragraph(
          'Di bagian atas pada halaman dashboard tersedia kotak pencarian, filter gedung, dan opsi '
          'urutan (Terbaru, A-Z, AQI Terbaik, AQI Terburuk). Kombinasi filter '
          'dapat dipakai bersamaan, jika hasil kosong, coba reset filter '
          'dengan tombol "Reset Filter & Pencarian".',
        ),
        const SizedBox(height: 16),
        _miniHeading('Angka AQI & Warna'),
        const SizedBox(height: 6),
        _paragraph(
          'Angka besar di dalam kotak berwarna adalah nilai AQI. Warna kotak '
          'mengikuti kategori AQI (hijau = Baik, biru = Sedang, kuning = Tidak '
          'Sehat, merah = Sangat Tidak Sehat, hitam = Berbahaya). Label di bawah dan di atas '
          'angka memberi tahu kategori secara tertulis.',
        ),
        const SizedBox(height: 14),
        _miniHeading('Kartu Parameter'),
        const SizedBox(height: 6),
        _paragraph(
          'Kartu PM2.5, PM10, CO, SO2, O3, NO2, Suhu, dan Kelembaban menampilkan nilai '
          'terkini beserta warna kategori masing-masing parameter. Angka di '
          'kartu ini adalah nilai mentah dari sensor, bukan AQI.',
        ),
        const SizedBox(height: 14),
        _miniHeading('Waktu Update'),
        const SizedBox(height: 6),
        _paragraph(
          'Di kartu ruangan tampil label seperti "UPDATE 14:30" atau '
          '"KEMARIN 18:05". Ini waktu terakhir data ruangan tersebut diperbarui. '
          'Jika data lebih dari beberapa jam, ruangan mungkin tidak aktif atau '
          'perangkat sedang offline.',
        ),
         const SizedBox(height: 14),
        _miniHeading('Rekomendasi & Dampak Kesehatan'),
        const SizedBox(height: 6),
        _paragraph(
          'Pada halaman detail ruangan, terdapat kartu berisi rekomendasi dan dampak kesehatan berdasarkan kategori AQI. '
          'setiap partikel juga memiliki rekomendasi tersendiri. Ketika nilai parameter berada di luar rentang aman '
          'akan muncul warning berwarna kuning atau merah yang akan menyesuaikan dengan tingkat di luar rentang amannya.'
        ),
        const SizedBox(height: 14),
        _miniHeading('Grafik Historis'),
        const SizedBox(height: 6),
        _paragraph(
          'Grafik di halaman detail ruangan menampilkan data 24 jam terakhir '
          'per interval 30 menit. Ketuk titik pada grafik untuk melihat '
          'informasi berisi nilai lengkap. Gunakan tombol parameter untuk '
          'mengganti metrik, dan ikon kalender untuk memilih tanggal lain.',
        ),
        const SizedBox(height: 14),
        _miniHeading('Indikator Server'),
        const SizedBox(height: 6),
        _paragraph(
          'Di pojok kanan bilah status terdapat titik kecil berwarna hijau atau merah. '
          'Hijau berarti server dapat dihubungi, sedangkan merah berarti perangkat tidak memiliki data internet atau server sedang tidak tersedia. '
        ),
      ],
    );
  }

  // ============================================================
  // 8. FAQ / TROUBLESHOOTING
  // ============================================================
  Widget _buildFAQ() {
    final faqs = <Map<String, String>>[
      {
        'q': 'Kenapa nilai AQI tidak berubah-ubah?',
        'a': 'Dahboard memperbarui data secara otomatis setiap 60 detik atau saat Anda menekan tombol refresh. '
            'Ketika tidak ada perubahan data yang terjadi, bisa jadi karena memang data belum berubah, atau disebabkan karena sumber pengambil data partikel ssedang tidak aktif, '
            'perangkat sedang tidak memiliki akses internet, atau server yang sedang tidak tersedia.'
      },
      {
        'q': 'Kenapa grafik kosong?',
        'a': 'Ada beberapa kemungkinan, (1) tanggal yang dipilih belum memiliki '
            'data historis, (2) server sedang offline, cek indikator titik di '
            'pojok kanan bilah status, (3) cache lokal belum terisi, coba refresh atau '
            'pilih tanggal hari ini.',
      },
      {
        'q': 'Kenapa muncul notifikasi "Server tidak dapat dihubungi"?',
        'a': 'Aplikasi gagal melakukan request ke backend. Periksa koneksi '
            'internet Anda, lalu cek indikator server (titik hijau/merah) di '
            'bilah status. Jika merah, kemungkinan backend sedang mati atau tidak '
            'dapat dijangkau.',
      },
      {
        'q': 'Kenapa data tidak muncul di dashboard meskipun server online?',
        'a': 'Periksa filter gedung dan kotak pencarian. Jika filter aktif dan '
            'tidak ada yang cocok, dashboard akan tampil kosong. Gunakan tombol '
            '"Reset Filter & Pencarian" untuk menampilkan semua ruangan kembali.',
      },
      {
        'q': 'Kenapa badge berubah dari "UPDATE" menjadi "KEMARIN"?',
        'a': 'Artinya data terakhir dari ruangan tersebut bukan dari hari ini. '
            'Silahkan laporkan ke kontak administrator jika terdapat ruangan yang tidak aktif lebih dari 24 jam.',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        ...faqs.map(
          (f) => Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ExpansionTile(
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                childrenPadding:
                    const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                title: Text(
                  f['q']!,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      f['a']!,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.55,
                        color: AppColors.textSecondary,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 9. TENTANG APLIKASI
  // ============================================================
  Widget _buildAbout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _paragraph(
          'UNILA Air Quality Index adalah sistem monitoring kualitas udara '
          'dalam ruangan yang dikembangkan untuk lingkungan dalam ruagnan Universitas Lampung.',
        ),
        const SizedBox(height: 16),
        _aboutRow(
            Icons.apps_rounded, 'Nama Aplikasi', 'UNILA Air Quality Index'),
        _aboutRow(Icons.tag_rounded, 'Versi', '1.0.0'),
        _aboutRow(Icons.school_rounded, 'Institusi', 'Universitas Lampung'),
        _aboutRow(Icons.email_outlined, 'Email',
            'fathannursidiq01@gmail.com'),
        const SizedBox(height: 16),
        Center(
          child: Text(
            '© ${DateTime.now().year} UNILA Air Quality Index',
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textHint,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ],
    );
  }

  Widget _aboutRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textHint),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textHint,
                fontFamily: 'Inter',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================
  Widget _breakpointTable({
    required List<String> headers,
    required List<List<String>> rows,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: headers
                .map(
                  (h) => Expanded(
                    child: Text(
                      h,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1),
          const SizedBox(height: 4),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: r
                    .map(
                      (v) => Expanded(
                        child: Text(
                          v,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Satuan konsentrasi: $unit',
              style: const TextStyle(
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
                color: AppColors.textHint,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

   Widget _paragraph(String text) {
    return Text(
      text,
      textAlign: TextAlign.justify,
      style: const TextStyle(
        fontSize: 13.5,
        height: 1.6,
        color: AppColors.textSecondary,
        fontFamily: 'Inter',
      ),
    );
  }

  Widget _subheading(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        fontFamily: 'Inter',
      ),
    );
  }

  Widget _miniHeading(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
        fontFamily: 'Inter',
      ),
    );
  }

  Widget _codeBox(String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        code,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
          color: AppColors.textPrimary,
          height: 1.55,
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textHint,
                fontFamily: 'Inter',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulletList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6, right: 8),
                      child:
                          Icon(Icons.circle, size: 5, color: AppColors.textHint),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.55,
                          color: AppColors.textSecondary,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

// ============================================================
// EXPANDABLE SECTION WIDGET
// ============================================================
class _ExpandableSection extends StatefulWidget {
  final String emoji;
  final String title;
  final Color color;
  final Widget child;
  final bool initiallyExpanded;

  const _ExpandableSection({
    required this.emoji,
    required this.title,
    required this.color,
    required this.child,
  }) : initiallyExpanded = false;

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection>
    with AutomaticKeepAliveClientMixin {
  late bool _expanded;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _expanded ? widget.color.withOpacity(0.35) : AppColors.border,
          width: _expanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_expanded ? 0.06 : 0.03),
            blurRadius: _expanded ? 10 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(widget.emoji,
                        style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: widget.color,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: widget.color.withOpacity(0.2), height: 1),
                  const SizedBox(height: 14),
                  widget.child,
                ],
              ),
            ),
        ],
      ),
    );
  }
}