const { calculateAQI } = require('./aqiCalculator');

const TIME_RANGES = {
  '06-08': {
    pm25:        { min: 8,  max: 20, mean: 14  },
    pm10:        { min: 15, max: 40, mean: 25  },
    co:          { min: 500, max: 2000, mean: 1000 },
    so2:         { min: 20, max: 60, mean: 40 },
    o3:          { min: 20, max: 80, mean: 50 },
    no2:         { min: 20, max: 70, mean: 45 },
    temperature: { min: 22, max: 26, mean: 24  },
    humidity:    { min: 65, max: 85, mean: 75  },
  },
  '08-12': {
    pm25:        { min: 15, max: 40, mean: 27  },
    pm10:        { min: 25, max: 80, mean: 50  },
    co:          { min: 1000, max: 4000, mean: 2500 },
    so2:         { min: 30, max: 100, mean: 60 },
    o3:          { min: 40, max: 120, mean: 80 },
    no2:         { min: 30, max: 100, mean: 60 },
    temperature: { min: 24, max: 29, mean: 26  },
    humidity:    { min: 55, max: 75, mean: 65  },
  },
  '12-16': {
    pm25:        { min: 18, max: 45, mean: 30  },
    pm10:        { min: 30, max: 90, mean: 55  },
    co:          { min: 1500, max: 6000, mean: 3500 },
    so2:         { min: 40, max: 140, mean: 80 },
    o3:          { min: 60, max: 160, mean: 110 },
    no2:         { min: 40, max: 120, mean: 80 },
    temperature: { min: 26, max: 32, mean: 29  },
    humidity:    { min: 50, max: 70, mean: 60  },
  },
  '16-18': {
    pm25:        { min: 12, max: 32, mean: 22  },
    pm10:        { min: 20, max: 65, mean: 40  },
    co:          { min: 1000, max: 4500, mean: 2500 },
    so2:         { min: 30, max: 110, mean: 60 },
    o3:          { min: 50, max: 140, mean: 90 },
    no2:         { min: 30, max: 100, mean: 60 },
    temperature: { min: 25, max: 30, mean: 27  },
    humidity:    { min: 55, max: 75, mean: 65  },
  },
  '18-20': {
    pm25:        { min: 10, max: 25, mean: 17  },
    pm10:        { min: 18, max: 50, mean: 32  },
    co:          { min: 600, max: 2500, mean: 1200 },
    so2:         { min: 20, max: 80, mean: 40 },
    o3:          { min: 30, max: 100, mean: 60 },
    no2:         { min: 20, max: 80, mean: 50 },
    temperature: { min: 24, max: 28, mean: 26  },
    humidity:    { min: 60, max: 80, mean: 70  },
  },
  '20-06': {
    pm25:        { min: 5,  max: 15, mean: 9   },
    pm10:        { min: 10, max: 30, mean: 18  },
    co:          { min: 300, max: 1500, mean: 800 },
    so2:         { min: 10, max: 50, mean: 25 },
    o3:          { min: 10, max: 60, mean: 30 },
    no2:         { min: 10, max: 50, mean: 30 },
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

function randomInRange(min, max, mean) {
  const mode = Math.max(min, Math.min(max, mean ?? (min + max) / 2));
  const u = Math.random();
  const f = (mode - min) / (max - min);

  if (u < f) {
    return min + Math.sqrt(u * (max - min) * (mode - min));
  }
  return max - Math.sqrt((1 - u) * (max - min) * (max - mode));
}

const generateSensorData = (roomType = 'normal') => {
  const now = new Date();
  const slot = getTimeSlot(now.getHours());
  const r = TIME_RANGES[slot];

  const pm25 = randomInRange(r.pm25.min, r.pm25.max, r.pm25.mean);
  const pm10 = randomInRange(r.pm10.min, r.pm10.max, r.pm10.mean);
  const co   = randomInRange(r.co.min,   r.co.max,   r.co.mean);
  const so2  = randomInRange(r.so2.min,  r.so2.max,  r.so2.mean);
  const o3   = randomInRange(r.o3.min,   r.o3.max,   r.o3.mean);
  const no2  = randomInRange(r.no2.min,  r.no2.max,  r.no2.mean);
  const temperature = randomInRange(r.temperature.min, r.temperature.max, r.temperature.mean);
  const humidity    = randomInRange(r.humidity.min,    r.humidity.max,    r.humidity.mean);

  const aqiResult = calculateAQI(pm25, pm10, co, so2, o3, no2);

  return {
    pm25: parseFloat(pm25.toFixed(1)),
    pm10: parseFloat(pm10.toFixed(1)),
    co: Math.round(co),
    so2: parseFloat(so2.toFixed(1)),
    o3: parseFloat(o3.toFixed(1)),
    no2: parseFloat(no2.toFixed(1)),
    temperature: parseFloat(temperature.toFixed(1)),
    humidity: Math.round(humidity),
    aqi: aqiResult.aqi,
    category: aqiResult.category,
    dominant: aqiResult.dominant,
    ispuPM25: aqiResult.ispuPM25,
    ispuPM10: aqiResult.ispuPM10,
    ispuCO: aqiResult.ispuCO,
    ispuSO2: aqiResult.ispuSO2,
    ispuO3: aqiResult.ispuO3,
    ispuNO2: aqiResult.ispuNO2,
    timeSlot: slot,
    timestamp: now,
    isAnomaly: false,
    anomalyType: null,
  };
};

const simulateAnomaly = (normalData) => {
  const roll = Math.random();

  // 5% SPIKE
  if (roll < 0.05) {
    const subRoll = Math.random();
    let multiplier;

    if (subRoll < 0.60) {
      multiplier = 8 + Math.random() * 2;
    } else if (subRoll < 0.90) {
      multiplier = 10 + Math.random() * 3;
    } else {
      multiplier = 13 + Math.random() * 4;
    }

    const pm25 = normalData.pm25 * multiplier;
    const pm10 = normalData.pm10 * multiplier;
    const co   = normalData.co * (1.5 + Math.random());
    const so2  = normalData.so2 * multiplier;
    const o3   = normalData.o3 * multiplier;
    const no2  = normalData.no2 * multiplier;

    const aqiResult = calculateAQI(pm25, pm10, co, so2, o3, no2);

    return {
      ...normalData,
      pm25: parseFloat(pm25.toFixed(1)),
      pm10: parseFloat(pm10.toFixed(1)),
      co: Math.round(co),
      so2: parseFloat(so2.toFixed(1)),
      o3: parseFloat(o3.toFixed(1)),
      no2: parseFloat(no2.toFixed(1)),
      aqi: aqiResult.aqi,
      category: aqiResult.category,
      dominant: aqiResult.dominant,
      ispuPM25: aqiResult.ispuPM25,
      ispuPM10: aqiResult.ispuPM10,
      ispuCO: aqiResult.ispuCO,
      ispuSO2: aqiResult.ispuSO2,
      ispuO3: aqiResult.ispuO3,
      ispuNO2: aqiResult.ispuNO2,
      isAnomaly: true,
      anomalyType: 'spike',
    };
  }

  // 3% SENSOR ERROR
  if (roll < 0.08) {
    return {
      ...normalData,
      pm25: -1,
      pm10: -1,
      co: -1,
      so2: -1,
      o3: -1,
      no2: -1,
      temperature: -1,
      humidity: -1,
      aqi: -1,
      category: 'error',
      isAnomaly: true,
      anomalyType: 'error',
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