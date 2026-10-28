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
// Time-based ranges (sama persis dengan backend)
// ============================================================
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

function randomInRange(min, max, mean) {
  const mode = Math.max(min, Math.min(max, mean ?? (min + max) / 2));
  const u = Math.random();
  const f = (mode - min) / (max - min);
  if (u < f) return min + Math.sqrt(u * (max - min) * (mode - min));
  return max - Math.sqrt((1 - u) * (max - min) * (max - mode));
}

// In-memory storage dengan update per 30 detik
const registeredDevices = new Map();
const deviceStates = new Map(); // State untuk setiap device
const secondDataCache = new Map(); // Cache data per 30 detik

// Helper: Generate data berdasarkan timestamp 30 detik
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

  // Sampling dari rentang slot
  const rawPm25 = randomInRange(r.pm25.min, r.pm25.max, r.pm25.mean);
  const rawPm10 = randomInRange(r.pm10.min, r.pm10.max, r.pm10.mean);
  const rawCo2  = randomInRange(r.co2.min,  r.co2.max,  r.co2.mean);
  const rawTemp = randomInRange(r.temperature.min, r.temperature.max, r.temperature.mean);
  const rawRh   = randomInRange(r.humidity.min,    r.humidity.max,    r.humidity.mean);

  // EMA smoothing supaya tidak jitter tiap 30 detik
  const alpha = 0.3;
  const prev = state.prevValues || {
    pm25: rawPm25, pm10: rawPm10, co2: rawCo2, temperature: rawTemp, humidity: rawRh,
  };
  const pm25 = prev.pm25 * (1 - alpha) + rawPm25 * alpha;
  const pm10 = prev.pm10 * (1 - alpha) + rawPm10 * alpha;
  const co2  = prev.co2  * (1 - alpha) + rawCo2  * alpha;
  const temperature = prev.temperature * (1 - alpha) + rawTemp * alpha;
  const humidity    = prev.humidity    * (1 - alpha) + rawRh   * alpha;

  state.prevValues = { pm25, pm10, co2, temperature, humidity };
  state.updateCounter++;
  state.last30SecondBlock = current30SecondBlock;

  // ✅ Hitung AQI via ISPU (max dari PM2.5 & PM10)
  const ispuPM25 = calculateISPUFromPM25(pm25);
  const ispuPM10 = calculateISPUFromPM10(pm10);
  const aqi = Math.max(ispuPM25, ispuPM10);
  const dominant = ispuPM25 >= ispuPM10 ? 'pm25' : 'pm10';

  let category;
  if (aqi <= 50) category = 'baik';
  else if (aqi <= 100) category = 'sedang';
  else if (aqi <= 200) category = 'tidak_sehat';
  else if (aqi <= 300) category = 'sangat_tidak_sehat';
  else category = 'berbahaya';

  const sensorData = {
    deviceId,
    timestamp: now.toISOString(),
    block30: current30SecondBlock,
    secondsInBlock: second % 30,
    updateCounter: state.updateCounter,
    aqi,
    ispuPM25,
    ispuPM10,
    dominant,
    pm25: parseFloat(pm25.toFixed(1)),
    pm10: parseFloat(pm10.toFixed(1)),
    co2: Math.round(co2),
    temperature: parseFloat(temperature.toFixed(1)),
    humidity: Math.round(humidity),
    category,
    roomType: ['Kelas', 'Laboratorium', 'Perpustakaan', 'Aula'][state.roomType],
    timeSlot: slot,
    factors: { hour, minute, second },
  };

  secondDataCache.set(deviceId, {
    block30: current30SecondBlock,
    data: sensorData,
    timestamp: now,
  });

  console.log(
    `🔄 ${deviceId} [${slot}] AQI=${aqi} (${dominant.toUpperCase()}), PM2.5=${sensorData.pm25}, PM10=${sensorData.pm10}`
  );

  return sensorData;
}

// Clean old cache entries setiap 60 detik
setInterval(() => {
  const now = Date.now();
  const currentBlock = Math.floor(now / (30 * 1000));
  
  for (const [deviceId, cache] of secondDataCache.entries()) {
    if (cache.block30 < currentBlock - 2) { // Hapus cache > 60 detik
      secondDataCache.delete(deviceId);
    }
  }
}, 60000); // Check setiap 60 detik

// Helper functions
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

// Create HTTP server
const server = http.createServer((req, res) => {
  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;
  const method = req.method;
  
  // Log request
  const now = new Date();
  console.log(`[${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}:${now.getSeconds().toString().padStart(2, '0')}] ${method} ${pathname}`);
  
  // Set CORS headers
  setCorsHeaders(res);
  
  // Handle CORS preflight
  if (method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }
  
  // Parse request body
  let body = '';
  req.on('data', chunk => {
    body += chunk.toString();
  });
  
  req.on('end', () => {
    let requestData = {};
    if (body && req.headers['content-type'] === 'application/json') {
      try {
        requestData = JSON.parse(body);
      } catch (e) {
        return sendJson(res, 400, {
          success: false,
          message: 'Invalid JSON'
        });
      }
    }
    
    try {
      // 1. Health check dengan info 30 detik
      if (pathname === '/health' && method === 'GET') {
        const now = new Date();
        const currentSecond = Math.floor(Date.now() / 1000);
        const current30SecondBlock = Math.floor(currentSecond / 30);
        const nextChangeInSeconds = 30 - (now.getSeconds() % 30);
        
        sendJson(res, 200, {
          status: 'ok',
          service: 'UNILA AQI IoT Simulator - 30 SECOND UPDATES',
          version: '3.0.0',
          currentTime: now.toISOString(),
          current30SecondBlock: current30SecondBlock,
          secondsInCurrentBlock: now.getSeconds() % 30,
          nextUpdateIn: nextChangeInSeconds,
          devices: registeredDevices.size,
          cacheSize: secondDataCache.size,
          features: [
            '30-second updates',
            'Predictable patterns',
            'Trend simulation',
            'Room type variations',
            'Time-of-day patterns'
          ]
        });
        return;
      }
      
      // 2. Register device
      if (pathname === '/register' && method === 'POST') {
        const { deviceId, deviceName, location, roomType } = requestData;
        
        if (!deviceId) {
          return sendJson(res, 400, {
            success: false,
            message: 'deviceId is required'
          });
        }
        
        // Map room type string to number
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
        
        console.log(`✅ Device registered: ${deviceId} (${['Kelas', 'Lab', 'Perpustakaan', 'Aula'][roomTypeNum]})`);
        
        sendJson(res, 200, {
          success: true,
          message: 'Device registered successfully',
          device: registeredDevices.get(deviceId),
          note: 'Data will update every 30 seconds based on time patterns'
        });
        return;
      }
      
      // 3. MAIN ENDPOINT: Get sensor data dengan update per 30 detik
      if (pathname.startsWith('/data/') && method === 'GET') {
        const deviceId = pathname.split('/')[2];
        
        if (!deviceId) {
          return sendJson(res, 400, {
            success: false,
            message: 'Device ID is required'
          });
        }
        
        // Auto-register jika belum ada
        if (!registeredDevices.has(deviceId)) {
          const hash = deviceId.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0);
          const roomType = hash % 4;
          
          registeredDevices.set(deviceId, {
            deviceId,
            deviceName: `Auto-${deviceId}`,
            location: 'UNILA Campus',
            roomType: roomType,
            registeredAt: new Date(),
            lastSeen: new Date(),
            status: 'active',
            updatePattern: '30-second-based-auto'
          });
          
          console.log(`✅ Auto-registered: ${deviceId} (${['Kelas', 'Lab', 'Perpustakaan', 'Aula'][roomType]})`);
        } else {
          // Update last seen
          const device = registeredDevices.get(deviceId);
          device.lastSeen = new Date();
          registeredDevices.set(deviceId, device);
        }
        
        // Generate data berdasarkan 30 detik
        const sensorData = generate30SecondBasedData(deviceId);
        
        // Hitung waktu sampai update berikutnya
        const now = new Date();
        const secondsRemaining = 30 - (now.getSeconds() % 30);
        
        // Response
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
            cacheInfo: 'Data changes at 30-second boundaries',
            units: {
              pm25: 'μg/m³',
              pm10: 'μg/m³',
              co2: 'ppm',
              temperature: '°C',
              humidity: '%'
            }
          }
        };
        
        sendJson(res, 200, response);
        return;
      }
      
      // 4. Get device status dengan info update
      if (pathname.startsWith('/status/') && method === 'GET') {
        const deviceId = pathname.split('/')[2];
        
        if (!deviceId) {
          return sendJson(res, 400, {
            success: false,
            message: 'Device ID is required'
          });
        }
        
        const deviceInfo = registeredDevices.get(deviceId);
        if (!deviceInfo) {
          return sendJson(res, 404, {
            success: false,
            message: 'Device not found'
          });
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
            current30SecondBlock: current30SecondBlock,
            secondsInCurrentBlock: now.getSeconds() % 30,
            nextUpdateInSeconds: secondsRemaining,
            hasCachedData: !!cache,
            cachedBlock: cache ? cache.block30 : null,
            stateInfo: state ? {
              roomType: ['Kelas', 'Laboratorium', 'Perpustakaan', 'Aula'][state.roomType],
              updateCounter: state.updateCounter,
              trends: { pm25: state.trendPM25, co2: state.trendCO2 }
            } : 'Not initialized'
          }
        });
        return;
      }
      
      // 5. Force update untuk testing (override cache)
      if (pathname.startsWith('/force-update/') && method === 'POST') {
        const deviceId = pathname.split('/')[2];
        
        if (!deviceId) {
          return sendJson(res, 400, {
            success: false,
            message: 'Device ID is required'
          });
        }
        
        // Clear cache untuk device ini
        secondDataCache.delete(deviceId);
        
        // Jika ada state, reset block untuk paksa update
        if (deviceStates.has(deviceId)) {
          const state = deviceStates.get(deviceId);
          state.last30SecondBlock = -1; // Force new block
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
      
      // 6. Set custom base values
      if (pathname.startsWith('/set-base/') && method === 'POST') {
        const deviceId = pathname.split('/')[2];
        const { pm25, pm10, co2, temperature, humidity, roomType } = requestData;
        
        if (!deviceId) {
          return sendJson(res, 400, {
            success: false,
            message: 'Device ID is required'
          });
        }
        
        if (!deviceStates.has(deviceId)) {
          // Initialize state dulu
          deviceStates.set(deviceId, {
            basePM25: 20,
            basePM10: 40,
            baseCO2: 550,
            baseTemp: 23,
            baseHumidity: 50,
            roomType: 0,
            trendPM25: 0,
            trendCO2: 0,
            last30SecondBlock: -1,
            updateCounter: 0
          });
        }
        
        const state = deviceStates.get(deviceId);
        
        // Update values
        if (pm25 !== undefined) state.basePM25 = pm25;
        if (pm10 !== undefined) state.basePM10 = pm10;
        if (co2 !== undefined) state.baseCO2 = co2;
        if (temperature !== undefined) state.baseTemp = temperature;
        if (humidity !== undefined) state.baseHumidity = humidity;
        if (roomType !== undefined) {
          if (roomType === 'laboratory' || roomType === 'lab') state.roomType = 1;
          else if (roomType === 'library') state.roomType = 2;
          else if (roomType === 'auditorium' || roomType === 'hall') state.roomType = 3;
          else state.roomType = 0;
        }
        
        // Clear cache
        secondDataCache.delete(deviceId);
        
        console.log(`🎯 Custom base set for ${deviceId}:`, {
          pm25: state.basePM25,
          temperature: state.baseTemp,
          roomType: ['Kelas', 'Lab', 'Perpustakaan', 'Aula'][state.roomType]
        });
        
        sendJson(res, 200, {
          success: true,
          message: 'Custom base values set',
          deviceId,
          values: {
            basePM25: state.basePM25,
            basePM10: state.basePM10,
            baseCO2: state.baseCO2,
            baseTemp: state.baseTemp,
            baseHumidity: state.baseHumidity,
            roomType: ['Kelas', 'Laboratorium', 'Perpustakaan', 'Aula'][state.roomType]
          }
        });
        return;
      }
      
      // 7. Get history (last N 30-second blocks)
      if (pathname.startsWith('/history/') && method === 'GET') {
        const deviceId = pathname.split('/')[2];
        const blocks = parseInt(parsedUrl.query.blocks) || 20; // Default 20 blocks = 10 menit
        
        if (!deviceId) {
          return sendJson(res, 400, {
            success: false,
            message: 'Device ID is required'
          });
        }
        
        // Simulasi data historis
        const now = new Date();
        const currentSecond = Math.floor(now.getTime() / 1000);
        const currentBlock = Math.floor(currentSecond / 30);
        const history = [];
        
        // Jika device punya state, generate historical data
        if (deviceStates.has(deviceId)) {
          const state = deviceStates.get(deviceId);
          
          for (let i = blocks; i >= 0; i--) {
            const historyBlock = currentBlock - i;
            const historyTime = new Date(now.getTime() - (i * 30 * 1000));
            
            // Gunakan algoritma yang sama tapi dengan offset
            const updateOffset = state.updateCounter - i;
            const hour = historyTime.getHours();
            const minute = historyTime.getMinutes();
            
            // Calculate historical values (simplified)
            let timeFactor = 1.0;
            if (hour >= 7 && hour <= 18) timeFactor = 1.2;
            
            const pm25 = state.basePM25 * timeFactor * (1 + Math.sin(updateOffset * 0.2) * 0.2);
            const pm10 = pm25 * 2;
            const co2 = state.baseCO2 * timeFactor;
            
            let aqi;
            if (pm25 <= 12.0) {
              aqi = Math.round((pm25 / 12.0) * 50);
            } else if (pm25 <= 35.4) {
              aqi = Math.round(51 + ((pm25 - 12.1) / (35.4 - 12.1)) * 49);
            } else {
              aqi = Math.round(101 + ((pm25 - 35.5) / (55.4 - 35.5)) * 49);
            }
            
            history.push({
              timestamp: historyTime.toISOString(),
              block: historyBlock,
              aqi: Math.min(500, aqi),
              pm25: parseFloat(pm25.toFixed(1)),
              pm10: parseFloat(pm10.toFixed(1)),
              co2: Math.round(co2),
              temperature: state.baseTemp + Math.sin(hour * 0.2618 + minute * 0.00436) * 3,
              humidity: state.baseHumidity + Math.cos(hour * 0.2618 + minute * 0.00436) * 10
            });
          }
        }
        
        sendJson(res, 200, {
          success: true,
          deviceId,
          period: `${blocks * 30} seconds (${blocks} blocks)`,
          currentBlock: currentBlock,
          count: history.length,
          data: history
        });
        return;
      }
      
      // 8. List all devices dengan info 30 detik
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
            currentBlock: currentBlock,
            nextUpdateIn: secondsRemaining
          };
        });
        
        sendJson(res, 200, {
          success: true,
          currentBlock: currentBlock,
          currentTime: now.toISOString(),
          secondsInCurrentBlock: now.getSeconds() % 30,
          nextUpdateInSeconds: secondsRemaining,
          totalDevices: devices.length,
          onlineDevices: devicesWithInfo.filter(d => d.status === 'online').length,
          devices: devicesWithInfo
        });
        return;
      }
      
      // 404 - Not Found
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

// Start server
const PORT = process.env.IOT_PORT || 3002;
const HOST = process.env.IOT_HOST || 'localhost';

server.listen(PORT, HOST, () => {
  console.log('🚀 UNILA AQI IoT Simulator - 30 SECOND UPDATES');
  console.log(`📍 URL: http://${HOST}:${PORT}`);
  console.log(`📡 Health Check: http://${HOST}:${PORT}/health`);
  
  console.log('\n⏰ FEATURE HIGHLIGHTS:');
  console.log('   ✅ Data BERUBAH SETIAP 30 DETIK');
  console.log('   ✅ Pola berdasarkan waktu (jam, hari)');
  console.log('   ✅ Trend gradual (naik/turun perlahan)');
  console.log('   ✅ Cache per 30 detik');
  console.log('   ✅ Room type variations');
  console.log('   ✅ Simulasi event (lonjakan periodik)');
  
  console.log('\n📋 Available Endpoints:');
  console.log(`  GET  /health                    - Health check dengan info 30 detik`);
  console.log(`  POST /register                 - Register device dengan room type`);
  console.log(`  GET  /data/:deviceId           - MAIN - Data updates setiap 30 detik`);
  console.log(`  GET  /status/:deviceId         - Status dengan countdown 30 detik`);
  console.log(`  POST /force-update/:deviceId   - Force new 30-second data`);
  console.log(`  POST /set-base/:deviceId       - Set custom base values`);
  console.log(`  GET  /history/:deviceId        - Historical 30-second data`);
  console.log(`  GET  /devices                  - List semua devices`);
  
  console.log('\n💡 Contoh untuk Aplikasi AQI:');
  console.log(`  Endpoint: http://${HOST}:${PORT}/data/kelas-h101`);
  console.log(`  Data akan berubah setiap 30 detik (pada detik ke-0 dan ke-30)`);
  console.log(`  Pattern: lebih tinggi jam 7-18, lebih rendah malam`);
  console.log(`  Weekend: 40% lebih rendah dari weekday`);
  
  // Log countdown setiap 30 detik
  setInterval(() => {
    const now = new Date();
    const seconds = now.getSeconds();
    const block30 = Math.floor(seconds / 30);
    const secondsRemaining = 30 - (seconds % 30);
    
    if (seconds % 30 === 0) {
      console.log(`🔄 30-second update boundary reached at ${now.getHours()}:${now.getMinutes().toString().padStart(2, '0')}:${now.getSeconds().toString().padStart(2, '0')}`);
    }
  }, 1000);
});