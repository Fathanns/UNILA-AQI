const { calculateAQI } = require('./aqiCalculator');

/**
 * Rentang nilai per slot waktu (sesuai tabel rentang waktu).
 * Unit: µg/m³ untuk PM, ppm untuk CO₂, °C untuk suhu, % untuk RH.
 */
const TIME_RANGES = {
  '06-08': {
    pm25:        { min: 8,  max: 20, mean: 14  },
    pm10:        { min: 15, max: 40, mean: 25  },
    co2:         { min: 420, max: 650,  mean: 520  },
    temperature: { min: 22, max: 26, mean: 24  },
    humidity:    { min: 65, max: 85, mean: 75  },
  },
  '08-12': {
    pm25:        { min: 15, max: 40, mean: 27  },
    pm10:        { min: 25, max: 80, mean: 50  },
    co2:         { min: 600, max: 1400, mean: 1000 },
    temperature: { min: 24, max: 29, mean: 26  },
    humidity:    { min: 55, max: 75, mean: 65  },
  },
  '12-16': {
    pm25:        { min: 18, max: 45, mean: 30  },
    pm10:        { min: 30, max: 90, mean: 55  },
    co2:         { min: 700, max: 1600, mean: 1100 },
    temperature: { min: 26, max: 32, mean: 29  },
    humidity:    { min: 50, max: 70, mean: 60  },
  },
  '16-18': {
    pm25:        { min: 12, max: 32, mean: 22  },
    pm10:        { min: 20, max: 65, mean: 40  },
    co2:         { min: 550, max: 1100, mean: 800  },
    temperature: { min: 25, max: 30, mean: 27  },
    humidity:    { min: 55, max: 75, mean: 65  },
  },
  '18-20': {
    pm25:        { min: 10, max: 25, mean: 17  },
    pm10:        { min: 18, max: 50, mean: 32  },
    co2:         { min: 500, max: 1000, mean: 700  },
    temperature: { min: 24, max: 28, mean: 26  },
    humidity:    { min: 60, max: 80, mean: 70  },
  },
  '20-06': {
    pm25:        { min: 5,  max: 15, mean: 9   },
    pm10:        { min: 10, max: 30, mean: 18  },
    co2:         { min: 420, max: 550, mean: 450 },
    temperature: { min: 22, max: 26, mean: 24  },
    humidity:    { min: 70, max: 90, mean: 80  },
  },
};

function getTimeSlot(hour) {
  if (hour >= 6  && hour < 8)  return '06-08';
  if (hour >= 8  && hour < 12) return '08-12';
  if (hour >= 12 && hour < 16) return '12-16';
  if (hour >= 16 && hour < 18) return '16-18';
  if (hour >= 18 && hour < 20) return '18-20';
  return '20-06';
}

/**
 * Triangular distribution: puncak di `mean`, dibatasi [min, max].
 * Menghasilkan data lebih natural daripada uniform.
 */
function randomInRange(min, max, mean) {
  const mode = Math.max(min, Math.min(max, mean ?? (min + max) / 2));
  const u = Math.random();
  const f = (mode - min) / (max - min);

  if (u < f) {
    return min + Math.sqrt(u * (max - min) * (mode - min));
  }
  return max - Math.sqrt((1 - u) * (max - min) * (max - mode));
}

/**
 * Generate data sensor berdasarkan slot waktu saat ini.
 * AQI dihitung via ISPU: MAX(ISPU_PM25, ISPU_PM10).
 *
 * @param {string} roomType - opsional (diabaikan; kompatibilitas dgn caller lama)
 */
const generateSensorData = (roomType = 'normal') => {
  const now = new Date();
  const slot = getTimeSlot(now.getHours());
  const r = TIME_RANGES[slot];

  const pm25 = randomInRange(r.pm25.min, r.pm25.max, r.pm25.mean);
  const pm10 = randomInRange(r.pm10.min, r.pm10.max, r.pm10.mean);
  const co2  = randomInRange(r.co2.min,  r.co2.max,  r.co2.mean);
  const temperature = randomInRange(r.temperature.min, r.temperature.max, r.temperature.mean);
  const humidity    = randomInRange(r.humidity.min,    r.humidity.max,    r.humidity.mean);

  const aqiResult = calculateAQI(pm25, pm10);

  return {
    pm25: parseFloat(pm25.toFixed(1)),
    pm10: parseFloat(pm10.toFixed(1)),
    co2: Math.round(co2),
    temperature: parseFloat(temperature.toFixed(1)),
    humidity: Math.round(humidity),
    aqi: aqiResult.aqi,
    category: aqiResult.category,
    dominant: aqiResult.dominant,     // 'pm25' | 'pm10'
    ispuPM25: aqiResult.ispuPM25,
    ispuPM10: aqiResult.ispuPM10,
    timeSlot: slot,
    timestamp: now,
  };
};

/**
 * Simulasi anomali (dipakai opsional). AQI juga dihitung via ISPU.
 */
const simulateAnomaly = (normalData) => {
  const roll = Math.random();

  if (roll < 0.05) {
    const pm25 = normalData.pm25 * (3 + Math.random() * 2);
    const pm10 = normalData.pm10 * (3 + Math.random() * 2);
    const aqiResult = calculateAQI(pm25, pm10);

    return {
      ...normalData,
      pm25: parseFloat(pm25.toFixed(1)),
      pm10: parseFloat(pm10.toFixed(1)),
      co2: Math.round(normalData.co2 * (1.5 + Math.random())),
      aqi: aqiResult.aqi,
      category: aqiResult.category,
      dominant: aqiResult.dominant,
      ispuPM25: aqiResult.ispuPM25,
      ispuPM10: aqiResult.ispuPM10,
    };
  }

  if (roll < 0.08) {
    return {
      ...normalData,
      pm25: -1,
      pm10: -1,
      co2: -1,
      aqi: -1,
      category: 'error',
    };
  }

  return normalData;
};

module.exports = {
  generateSensorData,
  simulateAnomaly,
  getTimeSlot,
  TIME_RANGES,
};