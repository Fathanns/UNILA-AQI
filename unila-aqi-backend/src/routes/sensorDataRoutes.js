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


module.exports = router;