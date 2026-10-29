/**
 * ISPU (Indeks Standar Pencemar Udara) Calculator
 * Berdasarkan PP No. 22 Tahun 2021 (Indonesia)
 */

const PM25_BREAKPOINTS = [
  { ispuLow: 0,   ispuHigh: 50,  concLow: 0,   concHigh: 55  },
  { ispuLow: 51,  ispuHigh: 100, concLow: 56,  concHigh: 150 },
  { ispuLow: 101, ispuHigh: 200, concLow: 151, concHigh: 250 },
  { ispuLow: 201, ispuHigh: 300, concLow: 251, concHigh: 350 },
  { ispuLow: 301, ispuHigh: 500, concLow: 351, concHigh: 500 },
];

const PM10_BREAKPOINTS = [
  { ispuLow: 0,   ispuHigh: 50,  concLow: 0,   concHigh: 50  },
  { ispuLow: 51,  ispuHigh: 100, concLow: 51,  concHigh: 150 },
  { ispuLow: 101, ispuHigh: 200, concLow: 151, concHigh: 350 },
  { ispuLow: 201, ispuHigh: 300, concLow: 351, concHigh: 420 },
  { ispuLow: 301, ispuHigh: 500, concLow: 421, concHigh: 500 },
];

function calculateISPUFromConcentration(concentration, breakpoints) {
  if (concentration == null || isNaN(concentration) || concentration < 0) {
    return 0;
  }

  for (const bp of breakpoints) {
    if (concentration <= bp.concHigh) {
      const concRange = bp.concHigh - bp.concLow;
      if (concRange === 0) return bp.ispuHigh;

      const ispu =
        ((bp.ispuHigh - bp.ispuLow) / concRange) *
          (concentration - bp.concLow) +
        bp.ispuLow;

      return Math.round(Math.max(0, Math.min(500, ispu)));
    }
  }

  return 500;
}

function calculateISPUFromPM25(pm25) {
  return calculateISPUFromConcentration(pm25, PM25_BREAKPOINTS);
}

function calculateISPUFromPM10(pm10) {
  return calculateISPUFromConcentration(pm10, PM10_BREAKPOINTS);
}

function calculateAQI(pm25, pm10) {
  const ispuPM25 = calculateISPUFromPM25(pm25);
  const ispuPM10 = calculateISPUFromPM10(pm10);
  const aqi = Math.max(ispuPM25, ispuPM10);
  const dominant = ispuPM25 >= ispuPM10 ? 'pm25' : 'pm10';

  const cat = getAQICategory(aqi);

  return {
    aqi,
    ispuPM25,
    ispuPM10,
    dominant,
    category: cat.category,
    color: cat.color,
    label: cat.label,
  };
}

function getAQICategory(aqi) {
  if (aqi <= 50)  return { category: 'baik',               color: '#00E400', label: 'Baik' };
  if (aqi <= 100) return { category: 'sedang',             color: '#0000FF', label: 'Sedang' };
  if (aqi <= 200) return { category: 'tidak_sehat',        color: '#FFFF00', label: 'Tidak Sehat' };
  if (aqi <= 300) return { category: 'sangat_tidak_sehat', color: '#FF0000', label: 'Sangat Tidak Sehat' };
  return { category: 'berbahaya', color: '#000000', label: 'Berbahaya' };
}

/**
 * Konversi nilai AQI/ISPU target → konsentrasi PM2.5 (approx).
 * Inverse interpolation dari breakpoint PP 22/2021.
 * Dipakai untuk DEMO MODE: set nilai AQI spesifik agar dosen bisa
 * melihat semua kategori tanpa menunggu random.
 */
function aqiToPm25(aqi) {
  if (aqi == null || isNaN(aqi) || aqi <= 0) return 0;
  const target = Math.min(500, aqi);

  for (const bp of PM25_BREAKPOINTS) {
    if (target <= bp.ispuHigh) {
      const ispuRange = bp.ispuHigh - bp.ispuLow;
      if (ispuRange === 0) return bp.concLow;
      const ratio = (target - bp.ispuLow) / ispuRange;
      const conc = bp.concLow + ratio * (bp.concHigh - bp.concLow);
      return Math.round(conc);
    }
  }
  return 500;
}

const evaluateParameter = (type, value) => {
  switch (type) {
    case 'pm25': {
      const ispu = calculateISPUFromPM25(value);
      const cat = getAQICategory(ispu);
      return { status: cat.category, color: cat.color, ispu };
    }
    case 'pm10': {
      const ispu = calculateISPUFromPM10(value);
      const cat = getAQICategory(ispu);
      return { status: cat.category, color: cat.color, ispu };
    }
    case 'co2':
      if (value <= 600)  return { status: 'baik',               color: '#00E400' };
      if (value <= 1000) return { status: 'sedang',             color: '#0000FF' };
      if (value <= 1500) return { status: 'tidak_sehat',        color: '#FFFF00' };
      if (value <= 2000) return { status: 'sangat_tidak_sehat', color: '#FF0000' };
      return { status: 'berbahaya', color: '#000000' };

    case 'temperature':
      if (value >= 24 && value <= 26) return { status: 'ideal', color: '#0066CC' };
      if (value >= 20 && value <= 28) return { status: 'normal', color: '#00E400' };
      if (value >= 18 && value <= 30) return { status: 'sedang', color: '#FFFF00' };
      return { status: 'tidak_ideal', color: '#FF7E00' };

    case 'humidity':
      if (value >= 40 && value <= 60) return { status: 'ideal', color: '#0066CC' };
      if (value >= 30 && value <= 70) return { status: 'normal', color: '#00E400' };
      if (value >= 20 && value <= 80) return { status: 'sedang', color: '#FFFF00' };
      return { status: 'tidak_ideal', color: '#FF7E00' };

    default:
      return { status: 'unknown', color: '#CCCCCC' };
  }
};

module.exports = {
  calculateISPUFromPM25,
  calculateISPUFromPM10,
  calculateAQI,
  getAQICategory,
  evaluateParameter,
  aqiToPm25,
  calculateAQIFromPM25: (pm25) => {
    const ispu = calculateISPUFromPM25(pm25);
    const cat = getAQICategory(ispu);
    return { aqi: ispu, category: cat.category, color: cat.color };
  },
};