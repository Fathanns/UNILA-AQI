// File: src/routes/sensorDataRoutes.js
const express = require('express');
const router = express.Router();
const SensorData = require('../models/SensorData');
const { authMiddleware } = require('../middleware/authMiddleware');

// GET sensor data for a room dengan data aggregation
router.get('/:roomId', authMiddleware, async (req, res) => {
  try {
    const { roomId } = req.params;
    
    // Ambil data 24 jam terakhir
    const now = new Date();
    const dateFilter = { timestamp: { $gte: new Date(now - 24 * 60 * 60 * 1000) } };
    
    // Ambil SEMUA data 24 jam (tanpa limit)
    const sensorData = await SensorData.find({
      roomId: roomId,
      ...dateFilter
    })
    .sort({ timestamp: 1 });
    // .limit(parseInt(limit)); // HAPUS LIMIT INI
    
    // Jika data terlalu banyak, lakukan sampling di frontend
    res.json({
      success: true,
      data: sensorData,
      count: sensorData.length,
      message: '24 hours data loaded'
    });
  } catch (error) {
    console.error('Error fetching sensor data:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching sensor data',
      error: error.message
    });
  }
});

// POST untuk generate sample historical data (testing)
router.post('/:roomId/generate-sample', authMiddleware, async (req, res) => {
  try {
    const { roomId } = req.params;
    const { hours = 24, interval = 15 } = req.body; // minutes
    
    const Room = require('../models/Room');
    const room = await Room.findById(roomId);
    
    if (!room) {
      return res.status(404).json({
        success: false,
        message: 'Room not found'
      });
    }
    
    const sampleData = [];
    const now = new Date();
    
    // Generate sample data untuk X jam terakhir
    for (let i = hours; i >= 0; i--) {
      const timestamp = new Date(now.getTime() - (i * 60 * 60 * 1000));
      
      // Generate multiple data points per hour
      for (let j = 0; j < 60/interval; j++) {
        const dataTime = new Date(timestamp.getTime() + (j * interval * 60 * 1000));
        
        // Random variation based on current room data
        const variation = 0.8 + Math.random() * 0.4;
        
        const pm25 = Math.max(0, room.currentData.pm25 * variation);
        const pm10 = Math.max(0, room.currentData.pm10 * variation);
        const co2 = Math.max(300, room.currentData.co2 * variation);
        const temperature = room.currentData.temperature + (Math.random() * 2 - 1);
        const humidity = Math.max(20, Math.min(90, room.currentData.humidity + (Math.random() * 10 - 5)));
        
        // Calculate AQI from PM2.5
        const { calculateAQIFromPM25 } = require('../utils/aqiCalculator');
        const { aqi, category } = calculateAQIFromPM25(pm25);
        
        sampleData.push({
          roomId: room._id,
          roomName: room.name,
          buildingName: room.buildingName,
          aqi: aqi,
          pm25: pm25,
          pm10: pm10,
          co2: co2,
          temperature: temperature,
          humidity: humidity,
          category: category,
          timestamp: dataTime
        });
      }
    }
    
    // Save sample data
    await SensorData.insertMany(sampleData);
    
    res.json({
      success: true,
      message: `Generated ${sampleData.length} sample data points`,
      count: sampleData.length,
      room: room.name
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error generating sample data',
      error: error.message
    });
  }
});

module.exports = router;