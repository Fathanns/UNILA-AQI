const express = require('express');
const router = express.Router();
const Building = require('../models/Building');
const Room = require('../models/Room');
const SensorData = require('../models/SensorData');

// Test endpoint untuk cek data
router.get('/status', async (req, res) => {
  try {
    const buildingCount = await Building.countDocuments();
    const roomCount = await Room.countDocuments();
    const sensorDataCount = await SensorData.countDocuments();
    
    // Get latest sensor data
    const latestData = await SensorData.findOne().sort({ timestamp: -1 });
    
    res.json({
      success: true,
      data: {
        buildings: buildingCount,
        rooms: roomCount,
        sensorData: sensorDataCount,
        latestUpdate: latestData ? latestData.timestamp : null,
        serverTime: new Date(),
        simulationRunning: true
      }
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      message: error.message 
    });
  }
});

// Get all buildings
router.get('/buildings', async (req, res) => {
  try {
    const buildings = await Building.find().sort({ name: 1 });
    res.json({
      success: true,
      count: buildings.length,
      data: buildings
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      message: error.message 
    });
  }
});

// Get all rooms
router.get('/rooms', async (req, res) => {
  try {
    const rooms = await Room.find()
      .populate('building', 'name code')
      .sort({ name: 1 });
    
    res.json({
      success: true,
      count: rooms.length,
      data: rooms
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      message: error.message 
    });
  }
});

module.exports = router;