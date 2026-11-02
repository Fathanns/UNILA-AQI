const http = require('http');
const url = require('url');

// ============================================================
// ISPU Calculator (sama persis dengan backend)
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

// ============================================================
// Time-based ranges
// Nilai CO disesuaikan dengan skala ISPU (µg/m³)
// ============================================================
const TIME_RANGES = {
  '06-08': {
    pm25:        { min: 8,  max: 20, mean: 14  },
    pm10:        { min: 15, max: 40, mean: 25  },
    co:          { min: 500, max: 2000, mean: 1000 },
    temperature: { min: 22, max: 26, mean: 24  },
    humidity:    { min: 65, max: 85, mean: 75  },
  },
  '08-12': {
    pm25:        { min: 15, max: 40, mean: 27  },
    pm10:        { min: 25, max: 80, mean: 50  },
    co:          { min: 1000, max: 4000, mean: 2500 },
    temperature: { min: 24, max: 29, mean: 26  },
    humidity:    { min: 55, max: 75, mean: 65  },
  },
  '12-16': {
    pm25:        { min: 18, max: 45, mean: 30  },
    pm10:        { min: 30, max: 90, mean: 55  },
    co:          { min: 1500, max: 6000, mean: 3500 },
    temperature: { min: 26, max: 32, mean: 29  },
    humidity:    { min: 50, max: 70, mean: 60  },
  },
  '16-18': {
    pm25:        { min: 12, max: 32, mean: 22  },
    pm10:        { min: 20, max: 65, mean: 40  },
    co:          { min: 1000, max: 4500, mean: 2500 },
    temperature: { min: 25, max: 30, mean: 27  },
    humidity:    { min: 55, max: 75, mean: 65  },
  },
  '18-20': {
    pm25:        { min: 10, max: 25, mean: 17  },
    pm10:        { min: 18, max: 50, mean: 32  },
    co:          { min: 600, max: 2500, mean: 1200 },
    temperature: { min: 24, max: 28, mean: 26  },
    humidity:    { min: 60, max: 80, mean: 70  },
  },
  '20-06': {
    pm25:        { min: 5,  max: 15, mean: 9   },
    pm10:        { min: 10, max: 30, mean: 18  },
    co:          { min: 300, max: 1500, mean: 800 },
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
function applyAnomaly(pm25, pm10, co, temperature, humidity) {
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
      temperature,
      humidity,
    };
  }

  if (roll < 0.08) {
    return {
      isAnomaly: true,
      anomalyType: 'error',
      pm25: -1, pm10: -1, co: -1, temperature: -1, humidity: -1,
    };
  }

  return {
    isAnomaly: false,
    anomalyType: null,
    pm25, pm10, co, temperature, humidity,
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
  const rawTemp = randomInRange(r.temperature.min, r.temperature.max, r.temperature.mean);
  const rawRh   = randomInRange(r.humidity.min,    r.humidity.max,    r.humidity.mean);

  const alpha = 0.4;
  const prev = state.prevValues || {
    pm25: rawPm25, pm10: rawPm10, co: rawCo,
    temperature: rawTemp, humidity: rawRh,
  };
  const pm25 = prev.pm25 * (1 - alpha) + rawPm25 * alpha;
  const pm10 = prev.pm10 * (1 - alpha) + rawPm10 * alpha;
  const co   = prev.co  * (1 - alpha) + rawCo  * alpha;
  const temperature = prev.temperature * (1 - alpha) + rawTemp * alpha;
  const humidity    = prev.humidity    * (1 - alpha) + rawRh   * alpha;

  // Update state (JANGAN feed anomali ke state — supaya spike transien 1 tick)
  state.prevValues = { pm25, pm10, co, temperature, humidity };
  state.updateCounter++;
  state.last30SecondBlock = current30SecondBlock;

  const anomalous = applyAnomaly(pm25, pm10, co, temperature, humidity);

  // Hitung AQI
  let finalAQI, finalCategory;
  if (anomalous.anomalyType === 'error') {
    finalAQI = -1;
    finalCategory = 'error';
  } else {
    const ispuPM25 = calculateISPUFromPM25(anomalous.pm25);
    const ispuPM10 = calculateISPUFromPM10(anomalous.pm10);
    finalAQI = Math.max(ispuPM25, ispuPM10);

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
    pm25: parseFloat(anomalous.pm25.toFixed(1)),
    pm10: parseFloat(anomalous.pm10.toFixed(1)),
    co: Math.round(anomalous.co),
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
      `🚨 ${deviceId} ANOMALY (${anomalous.anomalyType}): AQI=${finalAQI} (${finalCategory}), PM2.5=${sensorData.pm25}`
    );
  } else {
    console.log(
      `🔄 ${deviceId} [${slot}] AQI=${finalAQI}, PM2.5=${sensorData.pm25}, PM10=${sensorData.pm10}, CO=${sensorData.co}`
    );
  }

  return sensorData;
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
      if (pathname === '/health' && method === 'GET') {
        const now = new Date();
        const currentSecond = Math.floor(Date.now() / 1000);
        const current30SecondBlock = Math.floor(currentSecond / 30);
        const nextChangeInSeconds = 30 - (now.getSeconds() % 30);

        sendJson(res, 200, {
          status: 'ok',
          service: 'UNILA AQI IoT Simulator - 30 SECOND UPDATES',
          version: '6.0.0',
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
            'Time-of-day patterns'
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

        if (!registeredDevices.has(deviceId)) {
          const hash = deviceId.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0);
          const roomType = hash % 4;

          registeredDevices.set(deviceId, {
            deviceId,
            deviceName: `Auto-${deviceId}`,
            location: 'UNILA Campus',
            roomType,
            registeredAt: new Date(),
            lastSeen: new Date(),
            status: 'active',
            updatePattern: '30-second-based-auto'
          });

          console.log(`✅ Auto-registered: ${deviceId}`);
        } else {
          const device = registeredDevices.get(deviceId);
          device.lastSeen = new Date();
          registeredDevices.set(deviceId, device);
        }

        const sensorData = generate30SecondBasedData(deviceId);

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
            units: {
              pm25: 'μg/m³',
              pm10: 'μg/m³',
              co: 'μg/m³',
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
        const { pm25, pm10, co, temperature, humidity, roomType } = requestData;

        if (!deviceId) {
          return sendJson(res, 400, { success: false, message: 'Device ID is required' });
        }

        if (!deviceStates.has(deviceId)) {
          deviceStates.set(deviceId, {
            basePM25: 20, basePM10: 40, baseCO: 1500,
            baseTemp: 23, baseHumidity: 50, roomType: 0,
            trendPM25: 0, trendCO: 0, last30SecondBlock: -1, updateCounter: 0
          });
        }

        const state = deviceStates.get(deviceId);

        if (pm25 !== undefined) state.basePM25 = pm25;
        if (pm10 !== undefined) state.basePM10 = pm10;
        if (co !== undefined) state.baseCO = co;
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

            let aqi;
            if (pm25 <= 12.0) aqi = Math.round((pm25 / 12.0) * 50);
            else if (pm25 <= 35.4) aqi = Math.round(51 + ((pm25 - 12.1) / (35.4 - 12.1)) * 49);
            else aqi = Math.round(101 + ((pm25 - 35.5) / (55.4 - 35.5)) * 49);

            history.push({
              timestamp: historyTime.toISOString(),
              block: historyBlock,
              aqi: Math.min(500, aqi),
              pm25: parseFloat(pm25.toFixed(1)),
              pm10: parseFloat(pm10.toFixed(1)),
              co: Math.round(co),
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

const PORT = process.env.IOT_PORT || 3002;
const HOST = process.env.IOT_HOST || 'localhost';

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

  console.log('\n💡 Contoh untuk Aplikasi AQI:');
  console.log(`  Endpoint: http://${HOST}:${PORT}/data/kelas-h101`);
  console.log(`  Data akan berubah setiap 30 detik`);
  console.log(`  Sekitar 5% request akan menghasilkan AQI 100-500 (spike)`);
  console.log(`  Sekitar 3% request akan menghasilkan AQI=-1 (sensor error)`);
});