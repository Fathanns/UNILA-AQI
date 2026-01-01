// File: src/routes/buildingRoutes.js
const express = require('express');
const router = express.Router();
const Building = require('../models/Building');
const Room = require('../models/Room');
const { authMiddleware, adminMiddleware } = require('../middleware/authMiddleware');

// Helper untuk broadcast building update
const broadcastBuildingUpdate = (io, building, action, updatedRooms = []) => {
  if (io) {
    io.emit('building-updated', {
      action: action, // 'created', 'updated', 'deleted'
      building: building,
      updatedRooms: updatedRooms,
      timestamp: new Date()
    });
    
    // Broadcast ke room-specific channels untuk semua room yang terpengaruh
    updatedRooms.forEach(room => {
      io.to(room._id.toString()).emit('room-building-updated', {
        buildingId: building._id,
        oldBuildingName: room.buildingName,
        newBuildingName: building.name,
        timestamp: new Date()
      });
    });
  }
};

// GET all buildings (PUBLIC - untuk semua user)
router.get('/', async (req, res) => {
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
      message: 'Error fetching buildings',
      error: error.message
    });
  }
});

// GET single building (PUBLIC - untuk semua user)
router.get('/:id', async (req, res) => {
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

// POST create building (ADMIN ONLY)
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
    
    // Broadcast via Socket.io
    const io = req.app.get('socketio');
    if (io) {
      broadcastBuildingUpdate(io, building, 'created');
    }
    
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

// PUT update building (ADMIN ONLY) - PERBAIKAN UTAMA
router.put('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { name, code, description } = req.body;
    const io = req.app.get('socketio');
    
    const building = await Building.findById(req.params.id);
    
    if (!building) {
      return res.status(404).json({
        success: false,
        message: 'Building not found'
      });
    }
    
    // Simpan nama lama untuk perbandingan
    const oldName = building.name;
    
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
    
    // **PERBAIKAN UTAMA: Update buildingName di semua room yang terkait**
    let updatedRooms = [];
    if (name && name !== oldName) {
      // Find all rooms in this building
      const rooms = await Room.find({ building: building._id });
      
      // Update buildingName for each room
      const updatePromises = rooms.map(async (room) => {
        room.buildingName = building.name;
        room.updatedAt = new Date();
        await room.save();
        return room;
      });
      
      updatedRooms = await Promise.all(updatePromises);
      
      console.log(`✅ Updated building name for ${updatedRooms.length} rooms in ${building.name}`);
    }
    
    // **Broadcast via Socket.io untuk semua perubahan**
    if (io) {
      // Broadcast building update
      broadcastBuildingUpdate(io, building, 'updated', updatedRooms);
      
      // Broadcast individual room updates
      updatedRooms.forEach(room => {
        io.to(room._id.toString()).emit('room-update', {
          roomId: room._id,
          data: {
            currentAQI: room.currentAQI,
            currentData: room.currentData,
            updatedAt: room.updatedAt,
            buildingName: room.buildingName // Include updated building name
          },
          timestamp: new Date(),
          source: 'building-update',
          type: 'building-name-changed'
        });
        
        // Broadcast to dashboard untuk refresh
        io.emit('dashboard-update', {
          type: 'building-name-changed',
          buildingId: building._id,
          oldBuildingName: oldName,
          newBuildingName: building.name,
          affectedRooms: updatedRooms.map(r => r._id),
          timestamp: new Date()
        });
      });
    }
    
    res.json({
      success: true,
      message: 'Building updated successfully',
      data: building,
      updatedRoomsCount: updatedRooms.length
    });
  } catch (error) {
    console.error('Error updating building:', error);
    res.status(500).json({
      success: false,
      message: 'Error updating building',
      error: error.message
    });
  }
});

// DELETE building (ADMIN ONLY) - Perbaiki untuk broadcast
router.delete('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const buildingId = req.params.id;
    const io = req.app.get('socketio');
    
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
    
    // Broadcast via Socket.io
    if (io) {
      broadcastBuildingUpdate(io, building, 'deleted');
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

router.post('/:id/sync-rooms', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const buildingId = req.params.id;
    const io = req.app.get('socketio');
    
    const building = await Building.findById(buildingId);
    if (!building) {
      return res.status(404).json({
        success: false,
        message: 'Building not found'
      });
    }
    
    // Find all rooms in this building
    const rooms = await Room.find({ building: buildingId });
    
    // Update buildingName for each room
    const updatePromises = rooms.map(async (room) => {
      if (room.buildingName !== building.name) {
        room.buildingName = building.name;
        room.updatedAt = new Date();
        return await room.save();
      }
      return room;
    });
    
    const updatedRooms = (await Promise.all(updatePromises))
      .filter(room => room.buildingName === building.name);
    
    // Broadcast updates
    if (io && updatedRooms.length > 0) {
      updatedRooms.forEach(room => {
        io.to(room._id.toString()).emit('room-update', {
          roomId: room._id,
          data: {
            currentAQI: room.currentAQI,
            currentData: room.currentData,
            updatedAt: room.updatedAt,
            buildingName: room.buildingName
          },
          timestamp: new Date(),
          source: 'building-sync'
        });
      });
    }
    
    res.json({
      success: true,
      message: `Synced building name for ${updatedRooms.length} rooms`,
      building: building.name,
      updatedCount: updatedRooms.length
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error syncing building rooms',
      error: error.message
    });
  }
});

module.exports = router;