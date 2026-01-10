const express = require('express');
const router = express.Router();
const { seedSampleData, clearSampleData } = require('../utils/seedData');
const { authMiddleware, adminMiddleware } = require('../middleware/authMiddleware');
const SensorData = require('../models/SensorData');
const Room = require('../models/Room');

// Seed sample data (admin only)
router.post('/seed', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await seedSampleData();
    res.json(result);
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      message: 'Error seeding data',
      error: error.message 
    });
  }
});

// Clear sample data (admin only)
router.post('/clear', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await clearSampleData();
    res.json(result);
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      message: 'Error clearing data',
      error: error.message 
    });
  }
});

// SEED HISTORICAL DATA DUMMY (admin only)
router.post('/historical-data/:roomId', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { roomId } = req.params;
    const { days = 30, hours = 24 } = req.body;

    // Check if room exists
    const room = await Room.findById(roomId);
    if (!room) {
      return res.status(404).json({
        success: false,
        message: 'Room not found'
      });
    }

    // Delete existing historical data for this room
    await SensorData.deleteMany({ roomId: roomId });
    console.log(`🗑️ Deleted existing historical data for room ${room.name}`);

    const historicalData = [];
    const now = new Date();

    // Helper function untuk kategori AQI
    const getAQICategory = (aqi) => {
      if (aqi <= 50) return 'baik';
      if (aqi <= 100) return 'sedang';
      if (aqi <= 150) return 'tidak_sehat';
      if (aqi <= 200) return 'sangat_tidak_sehat';
      if (aqi <= 300) return 'berbahaya';
      return 'Berbahaya';
    };

    // Generate 30 days of historical data
    for (let day = days; day >= 0; day--) {
      const baseDate = new Date(now);
      baseDate.setDate(baseDate.getDate() - day);
      
      // For 30 days view: generate 1-3 data points per day
      const pointsPerDay = Math.floor(Math.random() * 3) + 1;
      
      for (let point = 0; point < pointsPerDay; point++) {
        // Random time during the day
        const randomHour = Math.floor(Math.random() * 24);
        const randomMinute = Math.floor(Math.random() * 60);
        
        const timestamp = new Date(baseDate);
        timestamp.setHours(randomHour, randomMinute, 0, 0);
        
        // Generate realistic AQI values (50-250)
        const aqi = Math.floor(Math.random() * 200) + 50;
        
        historicalData.push({
          roomId: roomId,
          roomName: room.name,
          buildingName: room.buildingName,
          aqi: aqi,
          pm25: (aqi / 5) + (Math.random() * 10),
          pm10: (aqi / 4) + (Math.random() * 15),
          co2: 400 + (Math.random() * 800),
          temperature: 22 + (Math.random() * 8),
          humidity: 40 + (Math.random() * 40),
          category: getAQICategory(aqi),
          timestamp: timestamp
        });
      }

      // For current day, generate 24 hours with 10-minute intervals
      if (day === 0) {
        for (let hour = 0; hour < hours; hour++) {
          for (let minute = 0; minute < 60; minute += 10) {
            const timestamp = new Date(now);
            timestamp.setHours(now.getHours() - hour, now.getMinutes() - minute, 0, 0);
            
            // Generate slightly varying AQI values
            const baseAqi = room.currentAQI || 75;
            const aqi = Math.max(0, baseAqi + (Math.random() * 40 - 20));
            
            historicalData.push({
              roomId: roomId,
              roomName: room.name,
              buildingName: room.buildingName,
              aqi: aqi,
              pm25: (aqi / 5) + (Math.random() * 5),
              pm10: (aqi / 4) + (Math.random() * 8),
              co2: 400 + (Math.random() * 600),
              temperature: 22 + (Math.random() * 6),
              humidity: 40 + (Math.random() * 30),
              category: getAQICategory(aqi),
              timestamp: timestamp
            });
          }
        }
      }
    }

    // Insert all historical data
    await SensorData.insertMany(historicalData);

    res.json({
      success: true,
      message: `Generated ${historicalData.length} historical data points for room ${room.name}`,
      data: {
        roomId: roomId,
        roomName: room.name,
        days: days,
        hours: hours,
        totalPoints: historicalData.length,
        timeRange: {
          oldest: historicalData[0]?.timestamp,
          newest: historicalData[historicalData.length - 1]?.timestamp
        }
      }
    });

    console.log(`✅ Generated ${historicalData.length} historical data points for room ${room.name}`);

  } catch (error) {
    console.error('❌ Error seeding historical data:', error);
    res.status(500).json({
      success: false,
      message: 'Error seeding historical data',
      error: error.message
    });
  }
});

// SEED HISTORICAL DATA FOR ALL ROOMS (admin only)
router.post('/historical-data-all', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { days = 30, hours = 24 } = req.body;

    // Get all active rooms
    const rooms = await Room.find({ isActive: true });
    
    if (rooms.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'No active rooms found'
      });
    }

    let totalPoints = 0;
    const results = [];

    // Process each room
    for (const room of rooms) {
      // Delete existing historical data for this room
      await SensorData.deleteMany({ roomId: room._id });
      
      const historicalData = [];
      const now = new Date();

      // Helper function untuk kategori AQI
      const getAQICategory = (aqi) => {
        if (aqi <= 50) return 'Baik';
        if (aqi <= 100) return 'Sedang';
        if (aqi <= 150) return 'Tidak Sehat';
        if (aqi <= 200) return 'Sangat Tidak Sehat';
        if (aqi <= 300) return 'Berbahaya';
        return 'Berbahaya';
      };

      // Generate data untuk setiap room
      for (let day = days; day >= 0; day--) {
        const baseDate = new Date(now);
        baseDate.setDate(baseDate.getDate() - day);
        
        const pointsPerDay = Math.floor(Math.random() * 3) + 1;
        
        for (let point = 0; point < pointsPerDay; point++) {
          const randomHour = Math.floor(Math.random() * 24);
          const randomMinute = Math.floor(Math.random() * 60);
          
          const timestamp = new Date(baseDate);
          timestamp.setHours(randomHour, randomMinute, 0, 0);
          
          const aqi = Math.floor(Math.random() * 200) + 50;
          
          historicalData.push({
            roomId: room._id,
            roomName: room.name,
            buildingName: room.buildingName,
            aqi: aqi,
            pm25: (aqi / 5) + (Math.random() * 10),
            pm10: (aqi / 4) + (Math.random() * 15),
            co2: 400 + (Math.random() * 800),
            temperature: 22 + (Math.random() * 8),
            humidity: 40 + (Math.random() * 40),
            category: getAQICategory(aqi),
            timestamp: timestamp
          });
        }

        if (day === 0) {
          for (let hour = 0; hour < hours; hour++) {
            for (let minute = 0; minute < 60; minute += 10) {
              const timestamp = new Date(now);
              timestamp.setHours(now.getHours() - hour, now.getMinutes() - minute, 0, 0);
              
              const baseAqi = room.currentAQI || 75;
              const aqi = Math.max(0, baseAqi + (Math.random() * 40 - 20));
              
              historicalData.push({
                roomId: room._id,
                roomName: room.name,
                buildingName: room.buildingName,
                aqi: aqi,
                pm25: (aqi / 5) + (Math.random() * 5),
                pm10: (aqi / 4) + (Math.random() * 8),
                co2: 400 + (Math.random() * 600),
                temperature: 22 + (Math.random() * 6),
                humidity: 40 + (Math.random() * 30),
                category: getAQICategory(aqi),
                timestamp: timestamp
              });
            }
          }
        }
      }

      // Insert data untuk room ini
      if (historicalData.length > 0) {
        await SensorData.insertMany(historicalData);
        totalPoints += historicalData.length;
        
        results.push({
          roomId: room._id,
          roomName: room.name,
          points: historicalData.length
        });
        
        console.log(`✅ Generated ${historicalData.length} historical data points for room ${room.name}`);
      }
    }

    res.json({
      success: true,
      message: `Generated ${totalPoints} historical data points for ${rooms.length} rooms`,
      data: {
        totalRooms: rooms.length,
        totalPoints: totalPoints,
        results: results
      }
    });

  } catch (error) {
    console.error('❌ Error seeding historical data for all rooms:', error);
    res.status(500).json({
      success: false,
      message: 'Error seeding historical data',
      error: error.message
    });
  }
});

module.exports = router;