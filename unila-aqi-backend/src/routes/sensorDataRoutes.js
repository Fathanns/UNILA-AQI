const express = require('express');
const router = express.Router();
const SensorData = require('../models/SensorData');
const { authMiddleware } = require('../middleware/authMiddleware');

// GET sensor data for a room
router.get('/:roomId', authMiddleware, async (req, res) => {
  try {
    const { roomId } = req.params;
    const { range = '24h' } = req.query;
    
    let dateFilter = {};
    const now = new Date();
    
    // Set date range
    switch (range) {
      case '24h':
        dateFilter = { timestamp: { $gte: new Date(now - 24 * 60 * 60 * 1000) } };
        break;
      case '7d':
        dateFilter = { timestamp: { $gte: new Date(now - 7 * 24 * 60 * 60 * 1000) } };
        break;
      case '30d':
        dateFilter = { timestamp: { $gte: new Date(now - 30 * 24 * 60 * 60 * 1000) } };
        break;
      default:
        dateFilter = { timestamp: { $gte: new Date(now - 24 * 60 * 60 * 1000) } };
    }
    
    const sensorData = await SensorData.find({
      roomId: roomId,
      ...dateFilter
    })
    .sort({ timestamp: 1 })
    .limit(100); // Limit to 100 data points
    
    res.json({
      success: true,
      data: sensorData,
      count: sensorData.length,
      range: range
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching sensor data',
      error: error.message
    });
  }
});

module.exports = router;