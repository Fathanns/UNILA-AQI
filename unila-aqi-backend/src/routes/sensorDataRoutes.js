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

// 🔥 BARU: GET historical AQI data 24 jam dengan interval 10 menit
router.get('/:roomId/historical/24h', authMiddleware, async (req, res) => {
  try {
    const { roomId } = req.params;
    
    // Validasi roomId
    if (!mongoose.Types.ObjectId.isValid(roomId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid room ID format'
      });
    }
    
    const now = new Date();
    const twentyFourHoursAgo = new Date(now - 24 * 60 * 60 * 1000);

    // Query untuk mendapatkan data setiap 10 menit dalam 24 jam terakhir
    const historicalData = await SensorData.aggregate([
      {
        $match: {
          roomId: toObjectId(roomId),
          timestamp: { 
            $gte: twentyFourHoursAgo,
            $lte: now 
          }
        }
      },
      {
        $addFields: {
          // Round timestamp to nearest 10 minutes
          roundedTime: {
            $dateFromParts: {
              year: { $year: "$timestamp" },
              month: { $month: "$timestamp" },
              day: { $dayOfMonth: "$timestamp" },
              hour: { $hour: "$timestamp" },
              minute: {
                $subtract: [
                  { $minute: "$timestamp" },
                  { $mod: [{ $minute: "$timestamp" }, 10] }
                ]
              },
              second: 0,
              millisecond: 0
            }
          }
        }
      },
      {
        $group: {
          _id: "$roundedTime",
          aqi: { $last: "$aqi" },
          timestamp: { $last: "$timestamp" },
          pm25: { $last: "$pm25" },
          pm10: { $last: "$pm10" },
          temperature: { $last: "$temperature" },
          humidity: { $last: "$humidity" },
          co2: { $last: "$co2" }
        }
      },
      {
        $sort: { _id: 1 }
      },
      {
        $project: {
          _id: 0,
          timestamp: "$_id",
          aqi: 1,
          pm25: 1,
          pm10: 1,
          temperature: 1,
          humidity: 1,
          co2: 1,
          hour: { $hour: "$_id" },
          minute: { $minute: "$_id" }
        }
      }
    ]);

    // Jika tidak ada data, return empty array
    res.json({
      success: true,
      data: historicalData || [],
      count: historicalData?.length || 0,
      timeRange: {
        start: twentyFourHoursAgo,
        end: now
      },
      message: historicalData?.length > 0 
        ? '24 hours historical data loaded' 
        : 'No historical data found for 24 hours'
    });
  } catch (error) {
    console.error('Error fetching 24h historical data:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching historical data',
      error: error.message
    });
  }
});

// 🔥 BARU: GET historical AQI data 30 hari dengan rata-rata harian
router.get('/:roomId/historical/30d', authMiddleware, async (req, res) => {
  try {
    const { roomId } = req.params;
    
    // Validasi roomId
    if (!mongoose.Types.ObjectId.isValid(roomId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid room ID format'
      });
    }
    
    const now = new Date();
    const thirtyDaysAgo = new Date(now - 30 * 24 * 60 * 60 * 1000);

    // Query untuk mendapatkan rata-rata harian dalam 30 hari terakhir
    const historicalData = await SensorData.aggregate([
      {
        $match: {
          roomId: toObjectId(roomId),
          timestamp: { 
            $gte: thirtyDaysAgo,
            $lte: now 
          }
        }
      },
      {
        $addFields: {
          date: {
            $dateFromParts: {
              year: { $year: "$timestamp" },
              month: { $month: "$timestamp" },
              day: { $dayOfMonth: "$timestamp" }
            }
          },
          dayOfWeek: { $dayOfWeek: "$timestamp" }
        }
      },
      {
        $group: {
          _id: "$date",
          date: { $first: "$date" },
          dayOfWeek: { $first: "$dayOfWeek" },
          avgAqi: { $avg: "$aqi" },
          maxAqi: { $max: "$aqi" },
          minAqi: { $min: "$aqi" },
          avgPm25: { $avg: "$pm25" },
          avgPm10: { $avg: "$pm10" },
          dataPoints: { $sum: 1 },
          lastTimestamp: { $max: "$timestamp" }
        }
      },
      {
        $sort: { date: 1 }
      },
      {
        $project: {
          _id: 0,
          date: 1,
          dayOfWeek: 1,
          aqi: { $round: ["$avgAqi", 1] },
          maxAqi: 1,
          minAqi: 1,
          pm25: { $round: ["$avgPm25", 1] },
          pm10: { $round: ["$avgPm10", 1] },
          dataPoints: 1,
          lastTimestamp: 1
        }
      }
    ]);

    // Format day names
    const dayNames = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    const formattedData = (historicalData || []).map(item => ({
      ...item,
      dayName: dayNames[item.dayOfWeek - 1],
      formattedDate: item.date.toISOString().split('T')[0],
      displayDate: `${item.date.getDate()}, ${dayNames[item.dayOfWeek - 1].substring(0, 3)}`
    }));

    res.json({
      success: true,
      data: formattedData,
      count: formattedData.length,
      timeRange: {
        start: thirtyDaysAgo,
        end: now
      },
      message: formattedData.length > 0 
        ? '30 days historical data loaded' 
        : 'No historical data found for 30 days'
    });
  } catch (error) {
    console.error('Error fetching 30d historical data:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching historical data',
      error: error.message
    });
  }
});

module.exports = router;