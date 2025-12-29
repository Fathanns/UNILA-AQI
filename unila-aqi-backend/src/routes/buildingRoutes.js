const express = require('express');
const router = express.Router();
const Building = require('../models/Building');
const Room = require('../models/Room');
const { authMiddleware, adminMiddleware } = require('../middleware/authMiddleware');

// GET all buildings
router.get('/:roomId', async (req, res) => {
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
    .limit(100);
    
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

// GET single building
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    const building = await Building.findById(req.params.id);
    
    if (!building) {
      return res.status(404).json({
        success: false,
        message: 'Building not found'
      });
    }
    
    res.json({
      success: true,
      data: building
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching building',
      error: error.message
    });
  }
});

// POST create building (admin only)
router.post('/', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { name, code, description } = req.body;
    
    // Validate required fields
    if (!name) {
      return res.status(400).json({
        success: false,
        message: 'Building name is required'
      });
    }
    
    // Check if code is unique
    if (code) {
      const existingBuilding = await Building.findOne({ code });
      if (existingBuilding) {
        return res.status(400).json({
          success: false,
          message: 'Building code already exists'
        });
      }
    }
    
    const building = new Building({
      name,
      code,
      description,
      roomCount: 0,
      createdAt: new Date(),
      updatedAt: new Date()
    });
    
    await building.save();
    
    res.status(201).json({
      success: true,
      message: 'Building created successfully',
      data: building
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error creating building',
      error: error.message
    });
  }
});

// PUT update building (admin only)
router.put('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { name, code, description } = req.body;
    
    const building = await Building.findById(req.params.id);
    
    if (!building) {
      return res.status(404).json({
        success: false,
        message: 'Building not found'
      });
    }
    
    // Simpan nama lama untuk pengecekan perubahan
    const oldBuildingName = building.name;
    
    // Check if new code is unique (if being changed)
    if (code && code !== building.code) {
      const existingBuilding = await Building.findOne({ code });
      if (existingBuilding) {
        return res.status(400).json({
          success: false,
          message: 'Building code already exists'
        });
      }
    }
    
    // Update fields
    if (name) building.name = name;
    if (code !== undefined) building.code = code;
    if (description !== undefined) building.description = description;
    building.updatedAt = new Date();
    
    await building.save();
    
    // Jika nama gedung berubah, update semua room yang terkait
    if (oldBuildingName !== building.name) {
      await Room.updateMany(
        { building: building._id },
        { $set: { buildingName: building.name } }
      );
      
      console.log(`✅ Updated building name for all rooms in ${building.name}`);
    }
    
    res.json({
      success: true,
      message: 'Building updated successfully',
      data: building
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error updating building',
      error: error.message
    });
  }
});

// DELETE building (admin only)
router.delete('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const buildingId = req.params.id;
    
    // Check if building has rooms
    const roomCount = await Room.countDocuments({ building: buildingId });
    
    if (roomCount > 0) {
      return res.status(400).json({
        success: false,
        message: 'Cannot delete building with existing rooms',
        roomCount: roomCount
      });
    }
    
    const building = await Building.findByIdAndDelete(buildingId);
    
    if (!building) {
      return res.status(404).json({
        success: false,
        message: 'Building not found'
      });
    }
    
    res.json({
      success: true,
      message: 'Building deleted successfully'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error deleting building',
      error: error.message
    });
  }
});

module.exports = router;