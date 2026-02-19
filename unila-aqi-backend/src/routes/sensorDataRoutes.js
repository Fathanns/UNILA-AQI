const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const SensorData = require('../models/SensorData');
const { authMiddleware } = require('../middleware/authMiddleware');

// Helper function untuk convert string ke ObjectId
const toObjectId = (id) => {
  try {
    return new mongoose.Types.ObjectId(id);
  } catch (error) {
    return null;
  }
};

// GET sensor data for a room dengan data aggregation
router.get('/:roomId', authMiddleware, async (req, res) => {
  try {
    const { roomId } = req.params;
    
    // Validasi roomId
    if (!mongoose.Types.ObjectId.isValid(roomId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid room ID format'
      });
    }
    
    // Ambil data 24 jam terakhir
    const now = new Date();
    const dateFilter = { timestamp: { $gte: new Date(now - 24 * 60 * 60 * 1000) } };
    
    // Ambil SEMUA data 24 jam (tanpa limit)
    const sensorData = await SensorData.find({
      roomId: toObjectId(roomId),
      ...dateFilter
    })
    .sort({ timestamp: 1 });
    
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

// NEW: GET sensor data by date untuk grafik history
router.get('/:roomId/history', authMiddleware, async (req, res) => {
  try {
    const { roomId } = req.params;
    const { date, interval = 30 } = req.query; // interval dalam menit
    
    // Validasi roomId
    if (!mongoose.Types.ObjectId.isValid(roomId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid room ID format'
      });
    }
    
    // Parse tanggal
    let startDate, endDate;
    if (date) {
      // Jika ada tanggal spesifik
      const selectedDate = new Date(date);
      startDate = new Date(selectedDate.setHours(0, 0, 0, 0));
      endDate = new Date(selectedDate.setHours(23, 59, 59, 999));
    } else {
      // Default: hari ini
      const today = new Date();
      startDate = new Date(today.setHours(0, 0, 0, 0));
      endDate = new Date(today.setHours(23, 59, 59, 999));
    }
    
    console.log(`📊 Fetching history data for room ${roomId} from ${startDate} to ${endDate}`);
    
    // Aggregation pipeline untuk data per interval
    const aggregationPipeline = [
      {
        $match: {
          roomId: toObjectId(roomId),
          timestamp: { $gte: startDate, $lte: endDate }
        }
      },
      {
        $addFields: {
          // Buat interval waktu (misal: 30 menit)
          timeInterval: {
            $subtract: [
              { $minute: "$timestamp" },
              { $mod: [{ $minute: "$timestamp" }, parseInt(interval)] }
            ]
          }
        }
      },
      {
        $group: {
          _id: {
            hour: { $hour: "$timestamp" },
            interval: "$timeInterval"
          },
          // Ambil data terakhir di setiap interval
          timestamp: { $last: "$timestamp" },
          aqi: { $last: "$aqi" },
          pm25: { $last: "$pm25" },
          pm10: { $last: "$pm10" },
          co2: { $last: "$co2" },
          temperature: { $last: "$temperature" },
          humidity: { $last: "$humidity" },
          category: { $last: "$category" },
          // Juga simpan data mentah untuk tooltip
          rawData: { $push: "$$ROOT" }
        }
      },
      {
        $sort: { "timestamp": 1 }
      },
      {
        $project: {
          _id: 0,
          timestamp: 1,
          hour: "$_id.hour",
          interval: "$_id.interval",
          timeLabel: {
            $concat: [
              { $toString: "$_id.hour" },
              ":",
              { 
                $cond: {
                  if: { $lt: ["$_id.interval", 10] },
                  then: "0",
                  else: ""
                }
              },
              { $toString: "$_id.interval" }
            ]
          },
          aqi: 1,
          pm25: 1,
          pm10: 1,
          co2: 1,
          temperature: 1,
          humidity: 1,
          category: 1,
          rawData: 1
        }
      }
    ];
    
    const aggregatedData = await SensorData.aggregate(aggregationPipeline);
    
    // Jika tidak ada data, coba ambil data mentah
    if (aggregatedData.length === 0) {
      const rawData = await SensorData.find({
        roomId: toObjectId(roomId),
        timestamp: { $gte: startDate, $lte: endDate }
      })
      .sort({ timestamp: 1 });
      
      return res.json({
        success: true,
        data: rawData.map(item => ({
          ...item.toObject(),
          timeLabel: `${item.timestamp.getHours()}:${item.timestamp.getMinutes().toString().padStart(2, '0')}`
        })),
        aggregated: false,
        count: rawData.length,
        message: 'Raw data loaded'
      });
    }
    
    res.json({
      success: true,
      data: aggregatedData, // Atau rawData
      aggregated: true, // Atau false
      count: aggregatedData.length,
      startDate: startDate,
      endDate: endDate,
      message: 'Aggregated history data loaded'
    });
    
  } catch (error) {
    console.error('Error fetching history data:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching history data',
      error: error.message
    });
  }
});

module.exports = router;