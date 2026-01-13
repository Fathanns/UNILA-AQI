const { calculateAQIFromPM25 } = require('./aqiCalculator');

/**
 * Generate random sensor data within realistic ranges
 */
const generateSensorData = (roomType = 'normal') => {
  // Base values depending on room type
  let basePM25, basePM10, baseCO2, baseTemp, baseHumidity;

  switch (roomType) {
    case 'laboratory':
      basePM25 = 8;
      basePM10 = 15;
      baseCO2 = 500;
      baseTemp = 23;
      baseHumidity = 50;
      break;
    case 'classroom':
      basePM25 = 12;
      basePM10 = 25;
      baseCO2 = 700;
      baseTemp = 25;
      baseHumidity = 55;
      break;
    case 'library':
      basePM25 = 6;
      basePM10 = 12;
      baseCO2 = 450;
      baseTemp = 22;
      baseHumidity = 48;
      break;
    case 'crowded':
      basePM25 = 25;
      basePM10 = 45;
      baseCO2 = 1200;
      baseTemp = 27;
      baseHumidity = 65;
      break;
    default: // normal
      basePM25 = 15;
      basePM10 = 30;
      baseCO2 = 600;
      baseTemp = 24;
      baseHumidity = 52;
  }

  // Add randomness (±30% of base value)
  const randomFactor = () => (Math.random() * 0.6) + 0.7; // 0.7 to 1.3

  const pm25 = Math.max(0, basePM25 * randomFactor());
  const pm10 = Math.max(0, basePM10 * randomFactor());
  const co2 = Math.max(300, baseCO2 * randomFactor());
  const temperature = baseTemp + (Math.random() * 4 - 2); // ±2°C
  const humidity = Math.max(20, Math.min(90, baseHumidity + (Math.random() * 10 - 5))); // ±5%

  // Calculate AQI from PM2.5
  const { aqi, category } = calculateAQIFromPM25(pm25);

  return {
    pm25: parseFloat(pm25.toFixed(1)),
    pm10: parseFloat(pm10.toFixed(1)),
    co2: Math.round(co2),
    temperature: parseFloat(temperature.toFixed(1)),
    humidity: Math.round(humidity),
    aqi,
    category,
    timestamp: new Date()
  };
};

const simulateAnomaly = (normalData) => {
  const anomalyType = Math.random();
  
  if (anomalyType < 0.05) { // 5% chance of anomaly
    // High pollution
    const highPollutionData = {
      ...normalData,
      pm25: normalData.pm25 * (3 + Math.random() * 2),
      pm10: normalData.pm10 * (3 + Math.random() * 2),
      co2: normalData.co2 * (1.5 + Math.random())
    };
    
    // Recalculate AQI for high pollution
    const { aqi, category } = calculateAQIFromPM25(highPollutionData.pm25);
    highPollutionData.aqi = Math.min(500, aqi);
    highPollutionData.category = category;
    
    return highPollutionData;
    
  } else if (anomalyType < 0.08) { // 3% chance
    // Sensor error (negative or extreme values)
    return {
      ...normalData,
      pm25: -1,
      pm10: -1,
      co2: -1,
      aqi: -1,
      category: 'error' // PASTIKAN 'error' ada di enum
    };
  }
  
  return normalData;
};

module.exports = {
  generateSensorData,
  generateTrendData,
  simulateAnomaly
};