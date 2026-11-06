const http = require('http');
const url = require('url');

// ============================================================
// ISPU Calculator (sama persis dengan backend aqiCalculator.js)
// ============================================================
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

const CO_BREAKPOINTS = [
  { ispuLow: 0,   ispuHigh: 50,  concLow: 0,     concHigh: 4000  },
  { ispuLow: 51,  ispuHigh: 100, concLow: 4001,  concHigh: 8000  },
  { ispuLow: 101, ispuHigh: 200, concLow: 8001,  concHigh: 15000 },
  { ispuLow: 201, ispuHigh: 300, concLow: 15001, concHigh: 30000 },
  { ispuLow: 301, ispuHigh: 500, concLow: 30001, concHigh: 45000 },
];

const SO2_BREAKPOINTS = [
  { ispuLow: 0,   ispuHigh: 50,  concLow: 0,    concHigh: 80   },
  { ispuLow: 51,  ispuHigh: 100, concLow: 81,   concHigh: 365  },
  { ispuLow: 101, ispuHigh: 200, concLow: 366,  concHigh: 800  },
  { ispuLow: 201, ispuHigh: 300, concLow: 801,  concHigh: 1600 },
  { ispuLow: 301, ispuHigh: 500, concLow: 1601, concHigh: 3000 },
];

const O3_BREAKPOINTS = [
  { ispuLow: 0,   ispuHigh: 50,  concLow: 0,   concHigh: 120  },
  { ispuLow: 51,  ispuHigh: 100, concLow: 121, concHigh: 235  },
  { ispuLow: 101, ispuHigh: 200, concLow: 236, concHigh: 400  },
  { ispuLow: 201, ispuHigh: 300, concLow: 401, concHigh: 800  },
  { ispuLow: 301, ispuHigh: 500, concLow: 801, concHigh: 1000 },
];

const NO2_BREAKPOINTS = [
  { ispuLow: 0,   ispuHigh: 50,  concLow: 0,    concHigh: 80   },
  { ispuLow: 51,  ispuHigh: 100, concLow: 81,   concHigh: 200  },
  { ispuLow: 101, ispuHigh: 200, concLow: 201,  concHigh: 1130 },
  { ispuLow: 201, ispuHigh: 300, concLow: 1131, concHigh: 2260 },
  { ispuLow: 301, ispuHigh: 500, concLow: 2261, concHigh: 3000 },
];

function calculateISPU(conc, bps) {
  if (conc == null || isNaN(conc) || conc < 0) return 0;
  for (const bp of bps) {
    if (conc <= bp.concHigh) {
      const range = bp.concHigh - bp.concLow;
      if (range === 0) return bp.ispuHigh;
      const ispu = ((bp.ispuHigh - bp.ispuLow) / range) * (conc - bp.concLow) + bp.ispuLow;
      return Math.round(Math.max(0, Math.min(500, ispu)));
    }
  }
  return 500;
}

const calculateISPUFromPM25 = (pm25) => calculateISPU(pm25, PM25_BREAKPOINTS);
const calculateISPUFromPM10 = (pm10) => calculateISPU(pm10, PM10_BREAKPOINTS);
const calculateISPUFromCO   = (co)   => calculateISPU(co,   CO_BREAKPOINTS);
const calculateISPUFromSO2  = (so2)  => calculateISPU(so2,  SO2_BREAKPOINTS);
const calculateISPUFromO3   = (o3)   => calculateISPU(o3,   O3_BREAKPOINTS);
const calculateISPUFromNO2  = (no2)  => calculateISPU(no2,  NO2_BREAKPOINTS);

// ============================================================
// Time-based ranges
// Nilai CO/SO2/O3/NO2 disesuaikan dengan skala ISPU (µg/m³)
// ============================================================
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
  if (u < f) return min + Math.sqrt(u * (max - min) * (mode - min));
  return max - Math.sqrt((1 - u) * (max - min) * (max - mode));
}

// In-memory storage
const registeredDevices = new Map();
const deviceStates = new Map();
const secondDataCache = new Map();

// ============================================================
// Anomaly simulation (SAMA dengan backend dataGenerator)
// 92% normal / 5% spike (8-17x) / 3% error
// ============================================================
function applyAnomaly(pm25, pm10, co, so2, o3, no2, temperature, humidity) {
  const roll = Math.random();

  if (roll < 0.05) {
    const subRoll = Math.random();
    let multiplier;
    if (subRoll < 0.60) {
      multiplier = 8 + Math.random() * 2;   // 8-10x
    } else if (subRoll < 0.90) {
      multiplier = 10 + Math.random() * 3;  // 10-13x
    } else {
      multiplier = 13 + Math.random() * 4;  // 13-17x
    }

    return {
      isAnomaly: true,
      anomalyType: 'spike',
      pm25: pm25 * multiplier,
      pm10: pm10 * multiplier,
      co: co * (1.5 + Math.random()), // Spike CO 1.5x - 2.5x dari nilai normal
      so2: so2 * multiplier,
      o3: o3 * multiplier,
      no2: no2 * multiplier,
      temperature,
      humidity,
    };
  }

  if (roll < 0.08) {
    return {
      isAnomaly: true,
      anomalyType: 'error',
      pm25: -1, pm10: -1, co: -1,
      so2: -1, o3: -1, no2: -1,
      temperature: -1, humidity: -1,
    };
  }

  return {
    isAnomaly: false,
    anomalyType: null,
    pm25, pm10, co, so2, o3, no2, temperature, humidity,
  };
}

// Helper: Generate data per 30 detik
function generate30SecondBasedData(deviceId) {
  const now = new Date();
  const currentSecond = Math.floor(now.getTime() / 1000);
  const current30SecondBlock = Math.floor(currentSecond / 30);
  const hour = now.getHours();
  const minute = now.getMinutes();
  const second = now.getSeconds();

  // Inisialisasi state device
  if (!deviceStates.has(deviceId)) {
    const hash = deviceId.split('').reduce((acc, c) => acc + c.charCodeAt(0), 0);
    deviceStates.set(deviceId, {
      roomType: hash % 4,
      prevValues: null,
      last30SecondBlock: current30SecondBlock - 1,
      updateCounter: 0,
    });
    console.log(`📊 Init device ${deviceId}:`, {
      roomType: ['Kelas', 'Laboratorium', 'Perpustakaan', 'Aula'][deviceStates.get(deviceId).roomType],
    });
  }

  const state = deviceStates.get(deviceId);

  // Cache 30 detik
  if (secondDataCache.has(deviceId)) {
    const cached = secondDataCache.get(deviceId);
    if (cached.block30 === current30SecondBlock) {
      return cached.data;
    }
  }

  const slot = getTimeSlot(hour);
  const r = TIME_RANGES[slot];

  const rawPm25 = randomInRange(r.pm25.min, r.pm25.max, r.pm25.mean);
  const rawPm10 = randomInRange(r.pm10.min, r.pm10.max, r.pm10.mean);
  const rawCo   = randomInRange(r.co.min,  r.co.max,  r.co.mean);
  const rawSo2  = randomInRange(r.so2.min, r.so2.max, r.so2.mean);
  const rawO3   = randomInRange(r.o3.min,  r.o3.max,  r.o3.mean);
  const rawNo2  = randomInRange(r.no2.min, r.no2.max, r.no2.mean);
  const rawTemp = randomInRange(r.temperature.min, r.temperature.max, r.temperature.mean);
  const rawRh   = randomInRange(r.humidity.min,    r.humidity.max,    r.humidity.mean);

  const alpha = 0.4;
  const prev = state.prevValues || {
    pm25: rawPm25, pm10: rawPm10, co: rawCo,
    so2: rawSo2, o3: rawO3, no2: rawNo2,
    temperature: rawTemp, humidity: rawRh,
  };
  const pm25 = prev.pm25 * (1 - alpha) + rawPm25 * alpha;
  const pm10 = prev.pm10 * (1 - alpha) + rawPm10 * alpha;
  const co   = prev.co  * (1 - alpha) + rawCo  * alpha;
  const so2  = prev.so2 * (1 - alpha) + rawSo2 * alpha;
  const o3   = prev.o3  * (1 - alpha) + rawO3  * alpha;
  const no2  = prev.no2 * (1 - alpha) + rawNo2 * alpha;
  const temperature = prev.temperature * (1 - alpha) + rawTemp * alpha;
  const humidity    = prev.humidity    * (1 - alpha) + rawRh   * alpha;

  // Update state (JANGAN feed anomali ke state — supaya spike transien 1 tick)
  state.prevValues = { pm25, pm10, co, so2, o3, no2, temperature, humidity };
  state.updateCounter++;
  state.last30SecondBlock = current30SecondBlock;

  const anomalous = applyAnomaly(pm25, pm10, co, so2, o3, no2, temperature, humidity);

  // Hitung AQI — konsisten dengan backend aqiCalculator.js
  let finalAQI, finalCategory, dominant;
  if (anomalous.anomalyType === 'error') {
    finalAQI = -1;
    finalCategory = 'error';
    dominant = null;
  } else {
    const ispuPM25 = calculateISPUFromPM25(anomalous.pm25);
    const ispuPM10 = calculateISPUFromPM10(anomalous.pm10);
    const ispuCO   = calculateISPUFromCO(anomalous.co);
    const ispuSO2  = calculateISPUFromSO2(anomalous.so2);
    const ispuO3   = calculateISPUFromO3(anomalous.o3);
    const ispuNO2  = calculateISPUFromNO2(anomalous.no2);

    // Tie-breaker: CO → SO2 → O3 → NO2 → PM2.5 → PM10
    const ordered = [
      { name: 'co',   value: ispuCO   },
      { name: 'so2',  value: ispuSO2  },
      { name: 'o3',   value: ispuO3   },
      { name: 'no2',  value: ispuNO2  },
      { name: 'pm25', value: ispuPM25 },
      { name: 'pm10', value: ispuPM10 },
    ];

    finalAQI = Math.max(...ordered.map((c) => c.value));
    dominant = ordered.find((c) => c.value === finalAQI).name;

    if (finalAQI <= 50) finalCategory = 'baik';
    else if (finalAQI <= 100) finalCategory = 'sedang';
    else if (finalAQI <= 200) finalCategory = 'tidak_sehat';
    else if (finalAQI <= 300) finalCategory = 'sangat_tidak_sehat';
    else finalCategory = 'berbahaya';
  }

  const sensorData = {
    deviceId,
    timestamp: now.toISOString(),
    block30: current30SecondBlock,
    secondsInBlock: second % 30,
    updateCounter: state.updateCounter,
    aqi: finalAQI,
    dominant,
    pm25: parseFloat(anomalous.pm25.toFixed(1)),
    pm10: parseFloat(anomalous.pm10.toFixed(1)),
    co: Math.round(anomalous.co),
    so2: parseFloat(anomalous.so2.toFixed(1)),
    o3: parseFloat(anomalous.o3.toFixed(1)),
    no2: parseFloat(anomalous.no2.toFixed(1)),
    temperature: parseFloat(anomalous.temperature.toFixed(1)),
    humidity: Math.round(anomalous.humidity),
    category: finalCategory,
    roomType: ['Kelas', 'Laboratorium', 'Perpustakaan', 'Aula'][state.roomType],
    timeSlot: slot,
    factors: { hour, minute, second },
    isAnomaly: anomalous.isAnomaly,
    anomalyType: anomalous.anomalyType,
  };

  secondDataCache.set(deviceId, {
    block30: current30SecondBlock,
    data: sensorData,
    timestamp: now,
  });

  if (anomalous.isAnomaly) {
    console.log(
      `🚨 ${deviceId} ANOMALY (${anomalous.anomalyType}): AQI=${finalAQI} (${finalCategory}), PM2.5=${sensorData.pm25}, dominant=${dominant}`
    );
  } else {
    console.log(
      `🔄 ${deviceId} [${slot}] AQI=${finalAQI} (${dominant}), PM2.5=${sensorData.pm25}, PM10=${sensorData.pm10}, CO=${sensorData.co}, SO2=${sensorData.so2}, O3=${sensorData.o3}, NO2=${sensorData.no2}`
    );
  }

  return sensorData;
}

function filterSensorData(data, fieldsQuery, excludeQuery) {
  const allFields = ['pm25','pm10','co','so2','o3','no2','temperature','humidity'];

  let selected;

  // ✅ Gunakan !== undefined agar `?fields=` (string kosong) tetap dianggap filter
  if (fieldsQuery !== undefined) {
    selected = new Set(
      fieldsQuery.split(',').map((f) => f.trim()).filter(Boolean)
    );
  } else if (excludeQuery !== undefined) {
    const excluded = new Set(
      excludeQuery.split(',').map((f) => f.trim()).filter(Boolean)
    );
    selected = new Set(allFields.filter((f) => !excluded.has(f)));
  } else {
    selected = new Set(allFields);
  }

  const result = { ...data };
  allFields.forEach((f) => {
    if (!selected.has(f)) result[f] = null;
  });

  // Recompute AQI dari field yang tersisa
  const has = (v) => typeof v === 'number' && !isNaN(v) && v >= 0;
  const ispus = [];
  if (has(result.pm25)) ispus.push({ name: 'pm25', value: calculateISPUFromPM25(result.pm25) });
  if (has(result.pm10)) ispus.push({ name: 'pm10', value: calculateISPUFromPM10(result.pm10) });
  if (has(result.co))   ispus.push({ name: 'co',   value: calculateISPUFromCO(result.co)   });
  if (has(result.so2))  ispus.push({ name: 'so2',  value: calculateISPUFromSO2(result.so2)  });
  if (has(result.o3))   ispus.push({ name: 'o3',   value: calculateISPUFromO3(result.o3)   });
  if (has(result.no2))  ispus.push({ name: 'no2',  value: calculateISPUFromNO2(result.no2)  });

  if (ispus.length === 0) {
    result.aqi = null;
    result.dominant = null;
    result.category = 'no_data';
  } else {
    const order = ['co', 'so2', 'o3', 'no2', 'pm25', 'pm10'];
    ispus.sort((a, b) => order.indexOf(a.name) - order.indexOf(b.name));
    const maxVal = Math.max(...ispus.map((i) => i.value));
    const dom = ispus.find((i) => i.value === maxVal);
    result.aqi = maxVal;
    result.dominant = dom.name;
    if (maxVal <= 50) result.category = 'baik';
    else if (maxVal <= 100) result.category = 'sedang';
    else if (maxVal <= 200) result.category = 'tidak_sehat';
    else if (maxVal <= 300) result.category = 'sangat_tidak_sehat';
    else result.category = 'berbahaya';
  }

  return result;
}

// Clean old cache setiap 30 detik
setInterval(() => {
  const now = Date.now();
  const currentBlock = Math.floor(now / (30 * 1000));

  for (const [deviceId, cache] of secondDataCache.entries()) {
    if (cache.block30 < currentBlock - 3) {
      secondDataCache.delete(deviceId);
    }
  }
}, 30000);

function setCorsHeaders(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
}

function sendJson(res, statusCode, data) {
  res.writeHead(statusCode, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*'
  });
  res.end(JSON.stringify(data, null, 2));
}

const server = http.createServer((req, res) => {
  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;
  const method = req.method;

  const now = new Date();
  console.log(`[${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}:${now.getSeconds().toString().padStart(2, '0')}] ${method} ${pathname}`);

  setCorsHeaders(res);

  if (method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  let body = '';
  req.on('data', chunk => { body += chunk.toString(); });

  req.on('end', () => {
    let requestData = {};
    if (body && req.headers['content-type'] === 'application/json') {
      try {
        requestData = JSON.parse(body);
      } catch (e) {
        return sendJson(res, 400, { success: false, message: 'Invalid JSON' });
      }
    }

    try {
      if (pathname === '/health' && (method === 'GET' || method === 'HEAD')) {
        const now = new Date();
        const currentSecond = Math.floor(Date.now() / 1000);
        const current30SecondBlock = Math.floor(currentSecond / 30);
        const nextChangeInSeconds = 30 - (now.getSeconds() % 30);

        sendJson(res, 200, {
          status: 'ok',
          service: 'UNILA AQI IoT Simulator - 30 SECOND UPDATES',
          version: '7.0.0',
          currentTime: now.toISOString(),
          current30SecondBlock,
          secondsInCurrentBlock: now.getSeconds() % 30,
          nextUpdateIn: nextChangeInSeconds,
          devices: registeredDevices.size,
          cacheSize: secondDataCache.size,
          features: [
            '30-second updates',
            'Predictable patterns',
            'Anomaly simulation (5% spike, 3% error)',
            'Room type variations',
            'Time-of-day patterns',
            'Full ISPU parameters (PM2.5, PM10, CO, SO2, O3, NO2)',
            'Dominant pollutant detection'
          ]
        });
        return;
      }

      if (pathname === '/register' && method === 'POST') {
        const { deviceId, deviceName, location, roomType } = requestData;

        if (!deviceId) {
          return sendJson(res, 400, { success: false, message: 'deviceId is required' });
        }

        let roomTypeNum = 0;
        if (roomType === 'laboratory' || roomType === 'lab') roomTypeNum = 1;
        else if (roomType === 'library') roomTypeNum = 2;
        else if (roomType === 'auditorium' || roomType === 'hall') roomTypeNum = 3;

        registeredDevices.set(deviceId, {
          deviceId,
          deviceName: deviceName || `Device-${deviceId.substring(0, 8)}`,
          location: location || 'UNILA Campus',
          roomType: roomTypeNum,
          registeredAt: new Date(),
          lastSeen: new Date(),
          status: 'active',
          updatePattern: '30-second-based'
        });

        console.log(`✅ Device registered: ${deviceId}`);

        sendJson(res, 200, {
          success: true,
          message: 'Device registered successfully',
          device: registeredDevices.get(deviceId),
        });
        return;
      }

      if (pathname.startsWith('/data/') && method === 'GET') {
        const deviceId = pathname.split('/')[2];

        if (!deviceId) {
          return sendJson(res, 400, { success: false, message: 'Device ID is required' });
        }

        // ---- Baca query param DULU ----
        const fieldsQuery  = parsedUrl.query.fields;
        const excludeQuery = parsedUrl.query.exclude;

        // ✅ Deteksi keberadaan query KEY, bukan truthiness value
        const hasFieldsFilter  = fieldsQuery !== undefined;
        const hasExcludeFilter = excludeQuery !== undefined;

        // ... auto-register, generate ...

        let sensorData = generate30SecondBasedData(deviceId);

        // ---- Filter SETELAH generate ----
        if (hasFieldsFilter || hasExcludeFilter) {
          sensorData = filterSensorData(sensorData, fieldsQuery, excludeQuery);
          console.log(
            `🔎 Filtered ${deviceId}: fields=${JSON.stringify(fieldsQuery)} exclude=${JSON.stringify(excludeQuery)} → AQI=${sensorData.aqi}, dominant=${sensorData.dominant}`
          );
        }

        // ---- 5. Bangun response (variabel `now` dst. seperti sebelumnya) ----
        const now = new Date();
        const secondsRemaining = 30 - (now.getSeconds() % 30);

        const response = {
          success: true,
          message: 'Sensor data (updates every 30 seconds)',
          device: registeredDevices.get(deviceId),
          data: sensorData,
          metadata: {
            source: 'UNILA AQI IoT Simulator - 30 SECOND UPDATES',
            updateFrequency: 'Every 30 seconds',
            currentBlock: sensorData.block30,
            secondsInCurrentBlock: sensorData.secondsInBlock,
            nextUpdateInSeconds: secondsRemaining,
            isAnomaly: sensorData.isAnomaly,
            anomalyType: sensorData.anomalyType,
             appliedFilter: {
              fields: hasFieldsFilter ? fieldsQuery : null,
              exclude: hasExcludeFilter ? excludeQuery : null,
            },
            units: {
              pm25: 'μg/m³',
              pm10: 'μg/m³',
              co: 'μg/m³',
              so2: 'μg/m³',
              o3: 'μg/m³',
              no2: 'μg/m³',
              temperature: '°C',
              humidity: '%'
            }
          }
        };

        sendJson(res, 200, response);
        return;
      }

      if (pathname.startsWith('/status/') && method === 'GET') {
        const deviceId = pathname.split('/')[2];

        if (!deviceId) {
          return sendJson(res, 400, { success: false, message: 'Device ID is required' });
        }

        const deviceInfo = registeredDevices.get(deviceId);
        if (!deviceInfo) {
          return sendJson(res, 404, { success: false, message: 'Device not found' });
        }

        const now = new Date();
        const lastSeen = new Date(deviceInfo.lastSeen);
        const secondsSinceLastSeen = (now - lastSeen) / 1000;
        const currentSecond = Math.floor(now.getTime() / 1000);
        const current30SecondBlock = Math.floor(currentSecond / 30);
        const secondsRemaining = 30 - (now.getSeconds() % 30);

        const state = deviceStates.get(deviceId);
        const cache = secondDataCache.get(deviceId);

        sendJson(res, 200, {
          success: true,
          device: deviceInfo,
          status: {
            online: secondsSinceLastSeen < 120,
            lastSeen: deviceInfo.lastSeen,
            secondsSinceLastSeen: Math.round(secondsSinceLastSeen),
            current30SecondBlock,
            secondsInCurrentBlock: now.getSeconds() % 30,
            nextUpdateInSeconds: secondsRemaining,
            hasCachedData: !!cache,
            cachedBlock: cache ? cache.block30 : null,
            stateInfo: state ? {
              roomType: ['Kelas', 'Laboratorium', 'Perpustakaan', 'Aula'][state.roomType],
              updateCounter: state.updateCounter,
            } : 'Not initialized'
          }
        });
        return;
      }

      if (pathname.startsWith('/force-update/') && method === 'POST') {
        const deviceId = pathname.split('/')[2];

        if (!deviceId) {
          return sendJson(res, 400, { success: false, message: 'Device ID is required' });
        }

        secondDataCache.delete(deviceId);

        if (deviceStates.has(deviceId)) {
          const state = deviceStates.get(deviceId);
          state.last30SecondBlock = -1;
        }

        console.log(`🔄 Force update triggered for ${deviceId}`);

        sendJson(res, 200, {
          success: true,
          message: 'Force update triggered',
          deviceId,
          note: 'Next request will generate new 30-second-based data'
        });
        return;
      }

      if (pathname.startsWith('/set-base/') && method === 'POST') {
        const deviceId = pathname.split('/')[2];
        const { pm25, pm10, co, so2, o3, no2, temperature, humidity, roomType } = requestData;

        if (!deviceId) {
          return sendJson(res, 400, { success: false, message: 'Device ID is required' });
        }

        if (!deviceStates.has(deviceId)) {
          deviceStates.set(deviceId, {
            basePM25: 20, basePM10: 40, baseCO: 1500,
            baseSO2: 40, baseO3: 60, baseNO2: 50,
            baseTemp: 23, baseHumidity: 50, roomType: 0,
            trendPM25: 0, trendCO: 0, last30SecondBlock: -1, updateCounter: 0
          });
        }

        const state = deviceStates.get(deviceId);

        if (pm25 !== undefined) state.basePM25 = pm25;
        if (pm10 !== undefined) state.basePM10 = pm10;
        if (co !== undefined) state.baseCO = co;
        if (so2 !== undefined) state.baseSO2 = so2;
        if (o3 !== undefined) state.baseO3 = o3;
        if (no2 !== undefined) state.baseNO2 = no2;
        if (temperature !== undefined) state.baseTemp = temperature;
        if (humidity !== undefined) state.baseHumidity = humidity;
        if (roomType !== undefined) {
          if (roomType === 'laboratory' || roomType === 'lab') state.roomType = 1;
          else if (roomType === 'library') state.roomType = 2;
          else if (roomType === 'auditorium' || roomType === 'hall') state.roomType = 3;
          else state.roomType = 0;
        }

        secondDataCache.delete(deviceId);

        sendJson(res, 200, {
          success: true,
          message: 'Custom base values set',
          deviceId,
          values: {
            basePM25: state.basePM25,
            basePM10: state.basePM10,
            baseCO: state.baseCO,
            baseSO2: state.baseSO2,
            baseO3: state.baseO3,
            baseNO2: state.baseNO2,
            baseTemp: state.baseTemp,
            baseHumidity: state.baseHumidity,
            roomType: ['Kelas', 'Laboratorium', 'Perpustakaan', 'Aula'][state.roomType]
          }
        });
        return;
      }

      if (pathname.startsWith('/history/') && method === 'GET') {
        const deviceId = pathname.split('/')[2];
        const blocks = parseInt(parsedUrl.query.blocks) || 60;

        if (!deviceId) {
          return sendJson(res, 400, { success: false, message: 'Device ID is required' });
        }

        const now = new Date();
        const currentSecond = Math.floor(now.getTime() / 1000);
        const currentBlock = Math.floor(currentSecond / 30);
        const history = [];

        if (deviceStates.has(deviceId)) {
          const state = deviceStates.get(deviceId);

          for (let i = blocks; i >= 0; i--) {
            const historyBlock = currentBlock - i;
            const historyTime = new Date(now.getTime() - (i * 30 * 1000));

            const updateOffset = state.updateCounter - i;
            const hour = historyTime.getHours();
            const minute = historyTime.getMinutes();

            let timeFactor = 1.0;
            if (hour >= 7 && hour <= 18) timeFactor = 1.2;

            const pm25 = state.basePM25 * timeFactor * (1 + Math.sin(updateOffset * 0.2) * 0.2);
            const pm10 = pm25 * 2;
            const co = state.baseCO * timeFactor;
            const so2 = (state.baseSO2 ?? 40) * timeFactor;
            const o3 = (state.baseO3 ?? 60) * timeFactor;
            const no2 = (state.baseNO2 ?? 50) * timeFactor;

            // AQI dihitung dari semua parameter (konsisten dgn backend)
            const ispuPM25 = calculateISPUFromPM25(pm25);
            const ispuPM10 = calculateISPUFromPM10(pm10);
            const ispuCO   = calculateISPUFromCO(co);
            const ispuSO2  = calculateISPUFromSO2(so2);
            const ispuO3   = calculateISPUFromO3(o3);
            const ispuNO2  = calculateISPUFromNO2(no2);
            const aqi = Math.min(500, Math.max(ispuPM25, ispuPM10, ispuCO, ispuSO2, ispuO3, ispuNO2));

            history.push({
              timestamp: historyTime.toISOString(),
              block: historyBlock,
              aqi,
              pm25: parseFloat(pm25.toFixed(1)),
              pm10: parseFloat(pm10.toFixed(1)),
              co: Math.round(co),
              so2: parseFloat(so2.toFixed(1)),
              o3: parseFloat(o3.toFixed(1)),
              no2: parseFloat(no2.toFixed(1)),
              temperature: state.baseTemp + Math.sin(hour * 0.2618 + minute * 0.00436) * 3,
              humidity: state.baseHumidity + Math.cos(hour * 0.2618 + minute * 0.00436) * 10
            });
          }
        }

        sendJson(res, 200, {
          success: true,
          deviceId,
          period: `${blocks * 30} seconds (${blocks} blocks)`,
          currentBlock,
          count: history.length,
          data: history
        });
        return;
      }

      if (pathname === '/devices' && method === 'GET') {
        const devices = Array.from(registeredDevices.values());
        const now = new Date();
        const currentSecond = Math.floor(now.getTime() / 1000);
        const currentBlock = Math.floor(currentSecond / 30);
        const secondsRemaining = 30 - (now.getSeconds() % 30);

        const devicesWithInfo = devices.map(device => {
          const lastSeen = new Date(device.lastSeen);
          const secondsSinceLastSeen = (now - lastSeen) / 1000;
          const state = deviceStates.get(device.deviceId);
          const cache = secondDataCache.get(device.deviceId);

          return {
            ...device,
            roomTypeName: ['Kelas', 'Laboratorium', 'Perpustakaan', 'Aula'][device.roomType || 0],
            status: secondsSinceLastSeen < 120 ? 'online' : 'offline',
            secondsSinceLastSeen: Math.round(secondsSinceLastSeen),
            hasState: !!state,
            updateCounter: state ? state.updateCounter : 0,
            cachedData: !!cache,
            cachedAtBlock: cache ? cache.block30 : null,
            currentBlock,
            nextUpdateIn: secondsRemaining
          };
        });

        sendJson(res, 200, {
          success: true,
          currentBlock,
          currentTime: now.toISOString(),
          secondsInCurrentBlock: now.getSeconds() % 30,
          nextUpdateInSeconds: secondsRemaining,
          totalDevices: devices.length,
          onlineDevices: devicesWithInfo.filter(d => d.status === 'online').length,
          devices: devicesWithInfo
        });
        return;
      }

      sendJson(res, 404, {
        success: false,
        message: 'Endpoint not found',
        path: pathname
      });

    } catch (error) {
      console.error('❌ Server error:', error);
      sendJson(res, 500, {
        success: false,
        message: 'Internal server error',
        error: error.message
      });
    }
  });
});

// ============================================================
// DEPLOY RENDER: bind 0.0.0.0 & gunakan process.env.PORT
// ============================================================
const PORT = process.env.PORT || process.env.IOT_PORT || 3002;
const HOST = '0.0.0.0'; // ✅ WAJIB untuk Render / Docker / VPS

server.listen(PORT, HOST, () => {
  console.log('🚀 UNILA AQI IoT Simulator - 30 SECOND UPDATES');
  console.log(`📍 URL: http://${HOST}:${PORT}`);
  console.log(`📡 Health Check: http://${HOST}:${PORT}/health`);

  console.log('\n⏰ FEATURE HIGHLIGHTS:');
  console.log('   ✅ Data BERUBAH SETIAP 30 DETIK');
  console.log('   ✅ Pola berdasarkan waktu (jam, hari)');
  console.log('   ✅ ANOMALY: 5% spike (8-17x), 3% sensor error');
  console.log('   ✅ Cache per 30 detik');
  console.log('   ✅ Room type variations');
  console.log('   ✅ EMA smoothing (alpha=0.4)');
  console.log('   ✅ ISPU untuk 6 parameter: PM2.5, PM10, CO, SO2, O3, NO2');
  console.log('   ✅ Dominant pollutant detection');

  console.log('\n💡 Contoh untuk Aplikasi AQI:');
  console.log(`  Endpoint: http://${HOST}:${PORT}/data/kelas-h101`);
  console.log(`  Data akan berubah setiap 30 detik`);
  console.log(`  Sekitar 5% request akan menghasilkan AQI 100-500 (spike)`);
  console.log(`  Sekitar 3% request akan menghasilkan AQI=-1 (sensor error)`);
});