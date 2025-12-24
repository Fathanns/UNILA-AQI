const express = require('express');
const router = express.Router();
const Room = require('../models/Room');
const Building = require('../models/Building');
const { authMiddleware, adminMiddleware } = require('../middleware/authMiddleware');

// GET all rooms
router.get('/', authMiddleware, async (req, res) => {
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
      message: 'Error fetching rooms',
      error: error.message
    });
  }
});

// GET single room
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    const room = await Room.findById(req.params.id)
      .populate('building', 'name code');
    
    if (!room) {
      return res.status(404).json({
        success: false,
        message: 'Room not found'
      });
    }
    
    res.json({
      success: true,
      data: room
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching room',
      error: error.message
    });
  }
});

// POST create room (admin only)
router.post('/', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { name, buildingId, dataSource, iotDeviceId, isActive } = req.body;
    
    // Validate required fields
    if (!name) {
      return res.status(400).json({
        success: false,
        message: 'Room name is required'
      });
    }
    
    if (!buildingId) {
      return res.status(400).json({
        success: false,
        message: 'Building ID is required'
      });
    }
    
    // Check if building exists
    const building = await Building.findById(buildingId);
    if (!building) {
      return res.status(404).json({
        success: false,
        message: 'Building not found'
      });
    }
    
    // Validate dataSource
    const validDataSources = ['simulation', 'iot'];
    if (dataSource && !validDataSources.includes(dataSource)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid data source. Must be "simulation" or "iot"'
      });
    }
    
    // For IoT source, iotDeviceId is required
    if (dataSource === 'iot' && !iotDeviceId) {
      return res.status(400).json({
        success: false,
        message: 'IoT Device ID is required for IoT data source'
      });
    }
    
    // Check if room name already exists in the same building
    const existingRoom = await Room.findOne({
      name: name.trim(),
      building: buildingId
    });
    
    if (existingRoom) {
      return res.status(400).json({
        success: false,
        message: 'Room name already exists in this building'
      });
    }
    
    const room = new Room({
      name: name.trim(),
      building: buildingId,
      buildingName: building.name,
      dataSource: dataSource || 'simulation',
      iotDeviceId: dataSource === 'iot' ? iotDeviceId : null,
      isActive: isActive !== undefined ? isActive : true,
      currentAQI: 0,
      currentData: {
        pm25: 0,
        pm10: 0,
        co2: 0,
        temperature: 0,
        humidity: 0,
        updatedAt: new Date()
      },
      createdAt: new Date(),
      updatedAt: new Date()
    });
    
    await room.save();
    
    // Update building room count
    building.roomCount = await Room.countDocuments({ building: buildingId });
    await building.save();
    
    res.status(201).json({
      success: true,
      message: 'Room created successfully',
      data: room
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error creating room',
      error: error.message
    });
  }
});

// PUT update room (admin only)
router.put('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { name, buildingId, dataSource, iotDeviceId, isActive } = req.body;
    
    const room = await Room.findById(req.params.id);
    
    if (!room) {
      return res.status(404).json({
        success: false,
        message: 'Room not found'
      });
    }
    
    // Validate dataSource if provided
    const validDataSources = ['simulation', 'iot'];
    if (dataSource && !validDataSources.includes(dataSource)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid data source. Must be "simulation" or "iot"'
      });
    }
    
    // For IoT source, iotDeviceId is required
    if (dataSource === 'iot' && !iotDeviceId) {
      return res.status(400).json({
        success: false,
        message: 'IoT Device ID is required for IoT data source'
      });
    }
    
    let buildingChanged = false;
    let oldBuildingId = null;
    
    // If building is being changed
    if (buildingId && buildingId !== room.building.toString()) {
      const newBuilding = await Building.findById(buildingId);
      if (!newBuilding) {
        return res.status(404).json({
          success: false,
          message: 'Building not found'
        });
      }
      
      // Check if room name already exists in the new building
      const existingRoom = await Room.findOne({
        name: name || room.name,
        building: buildingId,
        _id: { $ne: room._id }
      });
      
      if (existingRoom) {
        return res.status(400).json({
          success: false,
          message: 'Room name already exists in the new building'
        });
      }
      
      oldBuildingId = room.building;
      room.building = buildingId;
      room.buildingName = newBuilding.name;
      buildingChanged = true;
    } else if (name && name !== room.name) {
      // Check if room name already exists in the same building
      const existingRoom = await Room.findOne({
        name: name,
        building: room.building,
        _id: { $ne: room._id }
      });
      
      if (existingRoom) {
        return res.status(400).json({
          success: false,
          message: 'Room name already exists in this building'
        });
      }
    }
    
    // Update fields
    if (name) room.name = name.trim();
    if (dataSource !== undefined) {
      room.dataSource = dataSource;
      room.iotDeviceId = dataSource === 'iot' ? iotDeviceId : null;
    }
    if (iotDeviceId !== undefined && dataSource === 'iot') {
      room.iotDeviceId = iotDeviceId;
    }
    if (isActive !== undefined) room.isActive = isActive;
    room.updatedAt = new Date();
    
    await room.save();
    
    // Update building room counts if building changed
    if (buildingChanged) {
      // Update old building count
      if (oldBuildingId) {
        const oldBuilding = await Building.findById(oldBuildingId);
        if (oldBuilding) {
          oldBuilding.roomCount = await Room.countDocuments({ building: oldBuildingId });
          await oldBuilding.save();
        }
      }
      
      // Update new building count
      const newBuilding = await Building.findById(buildingId);
      if (newBuilding) {
        newBuilding.roomCount = await Room.countDocuments({ building: buildingId });
        await newBuilding.save();
      }
    }
    
    res.json({
      success: true,
      message: 'Room updated successfully',
      data: room
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error updating room',
      error: error.message
    });
  }
});

// DELETE room (admin only)
router.delete('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const room = await Room.findById(req.params.id);
    
    if (!room) {
      return res.status(404).json({
        success: false,
        message: 'Room not found'
      });
    }
    
    const buildingId = room.building;
    
    await room.deleteOne();
    
    // Update building room count
    const building = await Building.findById(buildingId);
    if (building) {
      building.roomCount = await Room.countDocuments({ building: buildingId });
      await building.save();
    }
    
    res.json({
      success: true,
      message: 'Room deleted successfully'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error deleting room',
      error: error.message
    });
  }
});

module.exports = router;