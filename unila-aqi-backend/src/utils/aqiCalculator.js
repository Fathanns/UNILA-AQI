/**
 * Calculate AQI based on PM2.5 concentration (US EPA Standard)
 * @param {number} pm25 - PM2.5 concentration in μg/m³
 * @returns {Object} {aqi, category, color}
 */
const calculateAQIFromPM25 = (pm25) => {
  let aqi, category, color;

  // US EPA AQI Breakpoints for PM2.5
  if (pm25 >= 0 && pm25 <= 12.0) {
    aqi = linearScale(pm25, 0, 12.0, 0, 50);
    category = 'baik';
    color = '#00E400'; // Hijau
  } else if (pm25 <= 35.4) {
    aqi = linearScale(pm25, 12.1, 35.4, 51, 100);
    category = 'sedang';
    color = '#FFFF00'; // Kuning
  } else if (pm25 <= 55.4) {
    aqi = linearScale(pm25, 35.5, 55.4, 101, 150);
    category = 'tidak_sehat';
    color = '#FF7E00'; // Oranye
  } else if (pm25 <= 150.4) {
    aqi = linearScale(pm25, 55.5, 150.4, 151, 200);
    category = 'sangat_tidak_sehat';
    color = '#FF0000'; // Merah
  } else if (pm25 <= 250.4) {
    aqi = linearScale(pm25, 150.5, 250.4, 201, 300);
    category = 'berbahaya';
    color = '#8F3F97'; // Ungu
  } else {
    aqi = linearScale(pm25, 250.5, 500.4, 301, 500);
    category = 'berbahaya';
    color = '#7E0023'; // Merah marun
  }

  return {
    aqi: Math.round(aqi),
    category,
    color
  };
};

/**
 * Linear interpolation for AQI calculation
 */
const linearScale = (C, Clow, Chigh, Ilow, Ihigh) => {
  return ((Ihigh - Ilow) / (Chigh - Clow)) * (C - Clow) + Ilow;
};

/**
 * Get category info based on AQI value
 */
const getAQICategory = (aqi) => {
  if (aqi <= 50) {
    return { category: 'baik', color: '#00E400', label: 'Baik' };
  } else if (aqi <= 100) {
    return { category: 'sedang', color: '#FFFF00', label: 'Sedang' };
  } else if (aqi <= 150) {
    return { category: 'tidak_sehat', color: '#FF7E00', label: 'Tidak Sehat' };
  } else if (aqi <= 200) {
    return { category: 'sangat_tidak_sehat', color: '#FF0000', label: 'Sangat Tidak Sehat' };
  } else if (aqi <= 300) {
    return { category: 'berbahaya', color: '#8F3F97', label: 'Berbahaya' };
  } else {
    return { category: 'berbahaya', color: '#7E0023', label: 'Berbahaya' };
  }
};

/**
 * Evaluate parameter status
 */
const evaluateParameter = (type, value) => {
  switch (type) {
    case 'pm25':
      if (value <= 12) return { status: 'baik', color: '#00E400' };
      if (value <= 35.4) return { status: 'sedang', color: '#FFFF00' };
      if (value <= 55.4) return { status: 'tidak_sehat', color: '#FF7E00' };
      if (value <= 150.4) return { status: 'sangat_tidak_sehat', color: '#FF0000' };
      return { status: 'berbahaya', color: '#8F3F97' };

    case 'pm10':
      if (value <= 54) return { status: 'baik', color: '#00E400' };
      if (value <= 154) return { status: 'sedang', color: '#FFFF00' };
      if (value <= 254) return { status: 'tidak_sehat', color: '#FF7E00' };
      if (value <= 354) return { status: 'sangat_tidak_sehat', color: '#FF0000' };
      return { status: 'berbahaya', color: '#8F3F97' };

    case 'co2':
      if (value <= 600) return { status: 'baik', color: '#00E400' };
      if (value <= 1000) return { status: 'sedang', color: '#FFFF00' };
      if (value <= 1500) return { status: 'tidak_sehat', color: '#FF7E00' };
      if (value <= 2000) return { status: 'sangat_tidak_sehat', color: '#FF0000' };
      return { status: 'berbahaya', color: '#8F3F97' };

    case 'temperature':
      if (value >= 22 && value <= 26) return { status: 'ideal', color: '#0066CC' };
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
  calculateAQIFromPM25,
  getAQICategory,
  evaluateParameter
};