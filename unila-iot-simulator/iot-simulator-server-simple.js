const http = require('http');
const url = require('url');

// In-memory storage dengan update per 30 detik
const registeredDevices = new Map();
const deviceStates = new Map(); // State untuk setiap device
const secondDataCache = new Map(); // Cache data per 30 detik

// Helper: Generate data berdasarkan timestamp 30 detik
function generate30SecondBasedData(deviceId) {
  const now = new Date();
  const currentSecond = Math.floor(now.getTime() / 1000);
  const current30SecondBlock = Math.floor(currentSecond / 30); // Block 30 detik
  const hour = now.getHours();
  const minute = now.getMinutes();
  const second = now.getSeconds();
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
      last30SecondBlock: current30SecondBlock - 1,
      updateCounter: 0
    });
    
    console.log(`📊 Initialized device ${deviceId}:`, {
      basePM25: deviceStates.get(deviceId).basePM25,
      roomType: ['Kelas', 'Laboratorium', 'Perpustakaan', 'Aula'][deviceStates.get(deviceId).roomType]
    });
  }
  
  const state = deviceStates.get(deviceId);
  
  // Cek jika masih di 30 detik block yang sama (cache)
  if (secondDataCache.has(deviceId)) {
    const cached = secondDataCache.get(deviceId);
    if (cached.block30 === current30SecondBlock) {
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
  
  // Update trends setiap beberapa update (setiap ~2.5 menit)
  if (current30SecondBlock > state.last30SecondBlock) {
    state.updateCounter++;
    state.last30SecondBlock = current30SecondBlock;
    
    // Setiap 5 update (150 detik / 2.5 menit), sedikit adjust trend
    if (state.updateCounter % 5 === 0) {
      // Small random adjustment to trend
      state.trendPM25 += (Math.random() - 0.5) * 0.2;
      state.trendCO2 += (Math.random() - 0.5) * 0.1;
      
      // Clamp trends
      state.trendPM25 = Math.max(-1, Math.min(1, state.trendPM25));
      state.trendCO2 = Math.max(-1, Math.min(1, state.trendCO2));
    }
    
    // Simulate events occasionally (every ~10 menit)
    if (state.updateCounter % 20 === 0 && Math.random() < 0.3) {
      console.log(`⚠️ Simulating event for ${deviceId} at update ${state.updateCounter}`);
      // Temporary spike
      timeFactor *= 1.8;
    }
  }
  
  // Calculate current values with trends
  const updateOffset = state.updateCounter;
  
  // PM2.5 dengan trend dan variasi
  const pm25Trend = state.trendPM25 * (updateOffset * 0.005);
  const pm30SecondVariation = Math.sin(updateOffset * 0.2) * 2; // Variasi sinusoidal
  const pm25Noise = (Math.random() - 0.5) * 0.5; // Small noise
  
  const pm25 = state.basePM25 * timeFactor * roomFactor * 
               (1 + pm25Trend + pm30SecondVariation * 0.1 + pm25Noise);
  
  // PM10 biasanya 1.8-2.2x PM2.5
  const pm10 = pm25 * (1.9 + Math.sin(updateOffset * 0.1) * 0.3);
  
  // CO2 dengan trend sendiri
  const co2Trend = state.trendCO2 * (updateOffset * 0.0025);
  const co230SecondVariation = Math.cos(updateOffset * 0.16) * 50;
  const co2 = state.baseCO2 * timeFactor * roomFactor * 
              (1 + co2Trend) + co230SecondVariation;
  
  // Temperature - gradual changes throughout day
  const tempBase = state.baseTemp;
  const tempDailyVariation = Math.sin(hour * 0.2618 + minute * 0.00436) * 3; // ±3°C daily cycle
  const temp30SecondVariation = Math.sin(updateOffset * 0.04) * 0.5; // Small variation per 30s
  
  const temperature = tempBase + tempDailyVariation + temp30SecondVariation;
  
  // Humidity - inverse of temperature
  const humidityBase = state.baseHumidity;
  const humidityDailyVariation = Math.cos(hour * 0.2618 + minute * 0.00436) * 10; // ±10%
  const humidity30SecondVariation = Math.cos(updateOffset * 0.06) * 2;
  
  const humidity = Math.max(30, Math.min(85, 
    humidityBase + humidityDailyVariation + humidity30SecondVariation));
  
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
    block30: current30SecondBlock,
    secondsInBlock: second % 30,
    updateCounter: state.updateCounter,
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
      minute: minute,
      second: second
    }
  };
  
  // Cache untuk 30 detik block ini
  secondDataCache.set(deviceId, {
    block30: current30SecondBlock,
    data: sensorData,
    timestamp: now
  });
  
  // Log perubahan jika block baru
  if (secondDataCache.size > 0) {
    const prevCache = Array.from(secondDataCache.values())
      .find(cache => cache.deviceId === deviceId);
    
    if (prevCache && prevCache.block30 !== current30SecondBlock) {
      console.log(`🔄 ${deviceId}: Block ${current30SecondBlock} (${now.getHours()}:${minute.toString().padStart(2, '0')}:${second.toString().padStart(2, '0')}) - AQI: ${aqi}, PM2.5: ${sensorData.pm25}`);
    }
  }
  
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