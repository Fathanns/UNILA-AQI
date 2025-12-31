const http = require('http');
const url = require('url');

// In-memory storage dengan update per menit
const registeredDevices = new Map();
const deviceStates = new Map(); // State untuk setiap device
const minuteDataCache = new Map(); // Cache data per menit

// Helper: Generate data berdasarkan timestamp menit
function generateMinuteBasedData(deviceId) {
  const now = new Date();
  const currentMinute = Math.floor(now.getTime() / (60 * 1000)); // Unix minute
  const hour = now.getHours();
  const minute = now.getMinutes();
  const dayOfWeek = now.getDay(); // 0 = Minggu, 6 = Sabtu
  
  // Jika device belum punya state, inisialisasi
  if (!deviceStates.has(deviceId)) {
    const hash = deviceId.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0);
    
    // State awal berdasarkan hash device
    deviceStates.set(deviceId, {
      basePM25: 20 + (hash % 25), // 20-45 μg/m³
      basePM10: 40 + (hash % 40), // 40-80 μg/m³
      baseCO2: 550 + (hash % 450), // 550-1000 ppm
      baseTemp: 23 + (hash % 7), // 23-30°C
      baseHumidity: 50 + (hash % 20), // 50-70%
      roomType: hash % 4, // 0: Kelas, 1: Lab, 2: Perpustakaan, 3: Aula
      trendPM25: (hash % 3) - 1, // -1: turun, 0: stabil, 1: naik
      trendCO2: (hash % 3) - 1,
      lastMinute: currentMinute - 1,
      minuteCounter: 0
    });
    
    console.log(`📊 Initialized device ${deviceId}:`, {
      basePM25: deviceStates.get(deviceId).basePM25,
      roomType: ['Kelas', 'Laboratorium', 'Perpustakaan', 'Aula'][deviceStates.get(deviceId).roomType]
    });
  }
  
  const state = deviceStates.get(deviceId);
  
  // Cek jika masih di menit yang sama (cache)
  if (minuteDataCache.has(deviceId)) {
    const cached = minuteDataCache.get(deviceId);
    if (cached.minute === currentMinute) {
      return cached.data;
    }
  }
  
  // Hitung faktor berdasarkan pola waktu
  let timeFactor = 1.0;
  
  // Pattern berdasarkan jam
  if (hour >= 7 && hour <= 9) { // Pagi (jam sibuk)
    timeFactor = 1.3;
  } else if (hour >= 10 && hour <= 12) { // Siang
    timeFactor = 1.1;
  } else if (hour >= 13 && hour <= 15) { // Sore
    timeFactor = 1.2;
  } else if (hour >= 16 && hour <= 18) { // Pulang kerja
    timeFactor = 1.4;
  } else if (hour >= 19 && hour <= 21) { // Malam
    timeFactor = 0.9;
  } else { // Tengah malam
    timeFactor = 0.7;
  }
  
  // Pattern berdasarkan hari
  if (dayOfWeek === 0 || dayOfWeek === 6) { // Weekend
    timeFactor *= 0.6; // Lebih rendah di weekend
  }
  
  // Pattern berdasarkan tipe ruangan
  let roomFactor = 1.0;
  switch(state.roomType) {
    case 0: // Kelas - tinggi di jam kuliah
      roomFactor = (hour >= 8 && hour <= 16) ? 1.4 : 0.8;
      break;
    case 1: // Laboratorium - stabil
      roomFactor = 1.0;
      break;
    case 2: // Perpustakaan - rendah
      roomFactor = 0.7;
      break;
    case 3: // Aula - tinggi saat event
      roomFactor = (hour >= 10 && hour <= 20) ? 1.6 : 0.9;
      break;
  }
  
  // Update trends setiap beberapa menit
  if (currentMinute > state.lastMinute) {
    state.minuteCounter++;
    state.lastMinute = currentMinute;
    
    // Setiap 5 menit, sedikit adjust trend
    if (state.minuteCounter % 5 === 0) {
      // Small random adjustment to trend
      state.trendPM25 += (Math.random() - 0.5) * 0.2;
      state.trendCO2 += (Math.random() - 0.5) * 0.1;
      
      // Clamp trends
      state.trendPM25 = Math.max(-1, Math.min(1, state.trendPM25));
      state.trendCO2 = Math.max(-1, Math.min(1, state.trendCO2));
    }
    
    // Simulate events occasionally (every 30 minutes)
    if (state.minuteCounter % 30 === 0 && Math.random() < 0.3) {
      console.log(`⚠️ Simulating event for ${deviceId} at minute ${state.minuteCounter}`);
      // Temporary spike
      timeFactor *= 1.8;
    }
  }
  
  // Calculate current values with trends
  const minuteOffset = state.minuteCounter;
  
  // PM2.5 dengan trend dan variasi menit
  const pm25Trend = state.trendPM25 * (minuteOffset * 0.01);
  const pm25MinuteVariation = Math.sin(minuteOffset * 0.1) * 2; // Sinusoidal variation
  const pm25Noise = (Math.random() - 0.5) * 0.5; // Small noise
  
  const pm25 = state.basePM25 * timeFactor * roomFactor * 
               (1 + pm25Trend + pm25MinuteVariation * 0.1 + pm25Noise);
  
  // PM10 biasanya 1.8-2.2x PM2.5
  const pm10 = pm25 * (1.9 + Math.sin(minuteOffset * 0.05) * 0.3);
  
  // CO2 dengan trend sendiri
  const co2Trend = state.trendCO2 * (minuteOffset * 0.005);
  const co2MinuteVariation = Math.cos(minuteOffset * 0.08) * 50;
  const co2 = state.baseCO2 * timeFactor * roomFactor * 
              (1 + co2Trend) + co2MinuteVariation;
  
  // Temperature - gradual changes throughout day
  const tempBase = state.baseTemp;
  const tempDailyVariation = Math.sin(hour * 0.2618 + minute * 0.00436) * 3; // ±3°C daily cycle
  const tempMinuteVariation = Math.sin(minuteOffset * 0.02) * 0.5; // Small minute variation
  
  const temperature = tempBase + tempDailyVariation + tempMinuteVariation;
  
  // Humidity - inverse of temperature
  const humidityBase = state.baseHumidity;
  const humidityDailyVariation = Math.cos(hour * 0.2618 + minute * 0.00436) * 10; // ±10%
  const humidityMinuteVariation = Math.cos(minuteOffset * 0.03) * 2;
  
  const humidity = Math.max(30, Math.min(85, 
    humidityBase + humidityDailyVariation + humidityMinuteVariation));
  
  // Calculate AQI
  let aqi;
  if (pm25 <= 12.0) {
    aqi = Math.round((pm25 / 12.0) * 50);
  } else if (pm25 <= 35.4) {
    aqi = Math.round(51 + ((pm25 - 12.1) / (35.4 - 12.1)) * 49);
  } else if (pm25 <= 55.4) {
    aqi = Math.round(101 + ((pm25 - 35.5) / (55.4 - 35.5)) * 49);
  } else if (pm25 <= 150.4) {
    aqi = Math.round(151 + ((pm25 - 55.5) / (150.4 - 55.5)) * 49);
  } else {
    aqi = Math.round(201 + ((pm25 - 150.5) / (250.4 - 150.5)) * 99);
  }
  
  aqi = Math.min(500, aqi);
  
  // AQI category
  let category;
  if (aqi <= 50) category = 'baik';
  else if (aqi <= 100) category = 'sedang';
  else if (aqi <= 150) category = 'tidak_sehat';
  else if (aqi <= 200) category = 'sangat_tidak_sehat';
  else category = 'berbahaya';
  
  // Create data object
  const sensorData = {
    deviceId,
    timestamp: now.toISOString(),
    minute: currentMinute,
    minuteCounter: state.minuteCounter,
    aqi,
    pm25: parseFloat(pm25.toFixed(1)),
    pm10: parseFloat(pm10.toFixed(1)),
    co2: Math.round(co2),
    temperature: parseFloat(temperature.toFixed(1)),
    humidity: Math.round(humidity),
    category,
    roomType: ['Kelas', 'Laboratorium', 'Perpustakaan', 'Aula'][state.roomType],
    trends: {
      pm25: parseFloat(state.trendPM25.toFixed(2)),
      co2: parseFloat(state.trendCO2.toFixed(2))
    },
    factors: {
      time: parseFloat(timeFactor.toFixed(2)),
      room: parseFloat(roomFactor.toFixed(2)),
      hour: hour,
      minute: minute
    }
  };
  
  // Cache untuk menit ini
  minuteDataCache.set(deviceId, {
    minute: currentMinute,
    data: sensorData,
    timestamp: now
  });
  
  // Log perubahan jika menit baru
  if (minuteDataCache.size > 0) {
    const prevCache = Array.from(minuteDataCache.values())
      .find(cache => cache.deviceId === deviceId);
    
    if (prevCache && prevCache.minute !== currentMinute) {
      console.log(`🔄 ${deviceId}: Menit ${currentMinute} - AQI: ${aqi}, PM2.5: ${sensorData.pm25}`);
    }
  }
  
  return sensorData;
}

// Clean old cache entries setiap 5 menit
setInterval(() => {
  const now = Date.now();
  const currentMinute = Math.floor(now / (60 * 1000));
  
  for (const [deviceId, cache] of minuteDataCache.entries()) {
    if (cache.minute < currentMinute - 2) { // Hapus cache > 2 menit
      minuteDataCache.delete(deviceId);
    }
  }
}, 30000); // Check setiap 30 detik

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
      // 1. Health check dengan info menit
      if (pathname === '/health' && method === 'GET') {
        const currentMinute = Math.floor(Date.now() / (60 * 1000));
        
        sendJson(res, 200, {
          status: 'ok',
          service: 'UNILA AQI IoT Simulator - MINUTE UPDATES',
          version: '3.0.0',
          currentMinute: currentMinute,
          currentTime: new Date().toISOString(),
          devices: registeredDevices.size,
          cacheSize: minuteDataCache.size,
          features: [
            'Minute-based updates',
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
          updatePattern: 'minute-based'
        });
        
        console.log(`✅ Device registered: ${deviceId} (${['Kelas', 'Lab', 'Perpustakaan', 'Aula'][roomTypeNum]})`);
        
        sendJson(res, 200, {
          success: true,
          message: 'Device registered successfully',
          device: registeredDevices.get(deviceId),
          note: 'Data will update every minute based on time patterns'
        });
        return;
      }
      
      // 3. MAIN ENDPOINT: Get sensor data dengan update per menit
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
            updatePattern: 'minute-based-auto'
          });
          
          console.log(`✅ Auto-registered: ${deviceId} (${['Kelas', 'Lab', 'Perpustakaan', 'Aula'][roomType]})`);
        } else {
          // Update last seen
          const device = registeredDevices.get(deviceId);
          device.lastSeen = new Date();
          registeredDevices.set(deviceId, device);
        }
        
        // Generate data berdasarkan menit
        const sensorData = generateMinuteBasedData(deviceId);
        
        // Response
        const response = {
          success: true,
          message: 'Sensor data (updates every minute)',
          device: registeredDevices.get(deviceId),
          data: sensorData,
          metadata: {
            source: 'UNILA AQI IoT Simulator - MINUTE UPDATES',
            updateFrequency: 'Every minute',
            currentMinute: sensorData.minute,
            cacheInfo: 'Data changes at minute boundaries',
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
        const currentMinute = Math.floor(now.getTime() / (60 * 1000));
        
        const state = deviceStates.get(deviceId);
        const cache = minuteDataCache.get(deviceId);
        
        sendJson(res, 200, {
          success: true,
          device: deviceInfo,
          status: {
            online: secondsSinceLastSeen < 120,
            lastSeen: deviceInfo.lastSeen,
            secondsSinceLastSeen: Math.round(secondsSinceLastSeen),
            currentMinute: currentMinute,
            nextMinuteChange: 60 - now.getSeconds(),
            hasCachedData: !!cache,
            cachedMinute: cache ? cache.minute : null,
            stateInfo: state ? {
              roomType: ['Kelas', 'Laboratorium', 'Perpustakaan', 'Aula'][state.roomType],
              minuteCounter: state.minuteCounter,
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
        minuteDataCache.delete(deviceId);
        
        // Jika ada state, reset minute counter untuk paksa update
        if (deviceStates.has(deviceId)) {
          const state = deviceStates.get(deviceId);
          state.lastMinute = -1; // Force new minute
        }
        
        console.log(`🔄 Force update triggered for ${deviceId}`);
        
        sendJson(res, 200, {
          success: true,
          message: 'Force update triggered',
          deviceId,
          note: 'Next request will generate new minute-based data'
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
            lastMinute: -1,
            minuteCounter: 0
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
        minuteDataCache.delete(deviceId);
        
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
      
      // 7. Get minute history (last N minutes)
      if (pathname.startsWith('/history/') && method === 'GET') {
        const deviceId = pathname.split('/')[2];
        const minutes = parseInt(parsedUrl.query.minutes) || 10;
        
        if (!deviceId) {
          return sendJson(res, 400, {
            success: false,
            message: 'Device ID is required'
          });
        }
        
        // Simulasi data historis
        const now = new Date();
        const currentMinute = Math.floor(now.getTime() / (60 * 1000));
        const history = [];
        
        // Jika device punya state, generate historical data
        if (deviceStates.has(deviceId)) {
          const state = deviceStates.get(deviceId);
          
          for (let i = minutes; i >= 0; i--) {
            const historyMinute = currentMinute - i;
            const historyTime = new Date(now.getTime() - (i * 60 * 1000));
            
            // Gunakan algoritma yang sama tapi dengan offset menit
            const minuteOffset = state.minuteCounter - i;
            const hour = historyTime.getHours();
            
            // Calculate historical values (simplified)
            let timeFactor = 1.0;
            if (hour >= 7 && hour <= 18) timeFactor = 1.2;
            
            const pm25 = state.basePM25 * timeFactor * (1 + Math.sin(minuteOffset * 0.1) * 0.2);
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
              minute: historyMinute,
              aqi: Math.min(500, aqi),
              pm25: parseFloat(pm25.toFixed(1)),
              pm10: parseFloat(pm10.toFixed(1)),
              co2: Math.round(co2),
              temperature: state.baseTemp + Math.sin(hour * 0.2618) * 3,
              humidity: state.baseHumidity + Math.cos(hour * 0.2618) * 10
            });
          }
        }
        
        sendJson(res, 200, {
          success: true,
          deviceId,
          period: `${minutes} minutes`,
          currentMinute: currentMinute,
          count: history.length,
          data: history
        });
        return;
      }
      
      // 8. List all devices dengan info menit
      if (pathname === '/devices' && method === 'GET') {
        const devices = Array.from(registeredDevices.values());
        const now = new Date();
        const currentMinute = Math.floor(now.getTime() / (60 * 1000));
        
        const devicesWithInfo = devices.map(device => {
          const lastSeen = new Date(device.lastSeen);
          const secondsSinceLastSeen = (now - lastSeen) / 1000;
          const state = deviceStates.get(device.deviceId);
          const cache = minuteDataCache.get(device.deviceId);
          
          return {
            ...device,
            roomTypeName: ['Kelas', 'Laboratorium', 'Perpustakaan', 'Aula'][device.roomType || 0],
            status: secondsSinceLastSeen < 120 ? 'online' : 'offline',
            secondsSinceLastSeen: Math.round(secondsSinceLastSeen),
            hasState: !!state,
            minuteCounter: state ? state.minuteCounter : 0,
            cachedData: !!cache,
            cachedAtMinute: cache ? cache.minute : null,
            currentMinute: currentMinute
          };
        });
        
        sendJson(res, 200, {
          success: true,
          currentMinute: currentMinute,
          currentTime: now.toISOString(),
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
  console.log('🚀 UNILA AQI IoT Simulator - MINUTE UPDATES');
  console.log(`📍 URL: http://${HOST}:${PORT}`);
  console.log(`📡 Health Check: http://${HOST}:${PORT}/health`);
  
  console.log('\n⏰ FEATURE HIGHLIGHTS:');
  console.log('   ✅ Data BERUBAH SETIAP 1 MENIT');
  console.log('   ✅ Pola berdasarkan waktu (jam, hari)');
  console.log('   ✅ Trend gradual (naik/turun perlahan)');
  console.log('   ✅ Cache per menit');
  console.log('   ✅ Room type variations');
  console.log('   ✅ Simulasi event (lonjakan periodik)');
  
  console.log('\n📋 Available Endpoints:');
  console.log(`  GET  /health                    - Health check with minute info`);
  console.log(`  POST /register                 - Register device with room type`);
  console.log(`  GET  /data/:deviceId           - MAIN - Data updates per minute`);
  console.log(`  GET  /status/:deviceId         - Status dengan countdown menit`);
  console.log(`  POST /force-update/:deviceId   - Force new minute data`);
  console.log(`  POST /set-base/:deviceId       - Set custom base values`);
  console.log(`  GET  /history/:deviceId        - Historical minute data`);
  console.log(`  GET  /devices                  - List semua devices`);
  
  console.log('\n💡 Contoh untuk Aplikasi AQI:');
  console.log(`  Endpoint: http://${HOST}:${PORT}/data/kelas-h101`);
  console.log(`  Data akan berubah setiap pergantian menit`);
  console.log(`  Pattern: lebih tinggi jam 7-18, lebih rendah malam`);
  console.log(`  Weekend: 40% lebih rendah dari weekday`);
});