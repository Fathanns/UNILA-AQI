// File: src/routes/roomRoutes.js
const express = require('express');
const router = express.Router();
const Room = require('../models/Room');
const Building = require('../models/Building');
const { authMiddleware, adminMiddleware } = require('../middleware/authMiddleware');

// Helper untuk broadcast room update
const broadcastRoomUpdate = (io, room, action, oldData = null) => {
  if (io) {
    const updateData = {
      action: action, // 'created', 'updated', 'deleted'
      room: {
        id: room._id,
        name: room.name,
        buildingId: room.building,
        buildingName: room.buildingName,
        dataSource: room.dataSource,
        iotDeviceId: room.iotDeviceId,
        isActive: room.isActive,
        currentAQI: room.currentAQI,
        currentData: room.currentData,
        createdAt: room.createdAt,
        updatedAt: room.updatedAt
      },
      oldData: oldData, // Untuk tracking perubahan
      timestamp: new Date()
    };
    
    // Broadcast ke channel spesifik room
    io.to(room._id.toString()).emit('room-updated', updateData);
    
    // Broadcast ke semua client di dashboard
    io.emit('dashboard-room-updated', updateData);
    
    // Broadcast perubahan spesifik jika ada
    if (oldData) {
      if (oldData.name !== room.name) {
        io.emit('room-name-changed', {
          roomId: room._id,
          oldName: oldData.name,
          newName: room.name,
          buildingName: room.buildingName,
          timestamp: new Date()
        });
      }
      
      if (oldData.buildingId !== room.building.toString()) {
        io.emit('room-building-changed', {
          roomId: room._id,
          oldBuildingId: oldData.buildingId,
          newBuildingId: room.building,
          oldBuildingName: oldData.buildingName,
          newBuildingName: room.buildingName,
          timestamp: new Date()
        });
      }
    }
    
    console.log(`📢 Broadcast room ${action}: ${room.name} (${room._id})`);
  }
};

// GET all rooms
router.get('/', async (req, res) => {
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
router.get('/:id', async (req, res) => {
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
    const io = req.app.get('socketio');
    
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
    
    // Create room with synced building name
    const room = new Room({
      name: name.trim(),
      building: buildingId,
      buildingName: building.name, // Get building name from Building collection
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
    
    // **PERBAIKAN: Broadcast room creation**
    if (io) {
      broadcastRoomUpdate(io, room, 'created');
    }
    
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

// PUT update room (admin only) - PERBAIKAN UTAMA
router.put('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { name, buildingId, dataSource, iotDeviceId, isActive } = req.body;
    const io = req.app.get('socketio');
    
    const room = await Room.findById(req.params.id)
      .populate('building', 'name');
    
    if (!room) {
      return res.status(404).json({
        success: false,
        message: 'Room not found'
      });
    }
    
    // **Simpan data lama untuk perbandingan**
    const oldData = {
      name: room.name,
      buildingId: room.building._id ? room.building._id.toString() : room.building.toString(),
      buildingName: room.buildingName,
      dataSource: room.dataSource,
      isActive: room.isActive
    };
    
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
    let newBuilding = null;
    
    // If building is being changed
    if (buildingId && buildingId !== room.building.toString()) {
      newBuilding = await Building.findById(buildingId);
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
      room.buildingName = newBuilding.name; // Update building name from new building
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
    
    // If building didn't change, ensure buildingName is synced
    if (!buildingChanged) {
      const currentBuilding = await Building.findById(room.building);
      if (currentBuilding && room.buildingName !== currentBuilding.name) {
        room.buildingName = currentBuilding.name;
      }
    }
    
    await room.save();
    
    // Update building room counts if building changed
    if (buildingChanged) {
      // Update old building count
      if (oldBuildingId) {
        const oldBuilding = await Building.findById(oldBuildingId);
        if (oldBuilding) {
          oldBuilding.roomCount = await Room.countDocuments({ building: oldBuildingId });
          await oldBuilding.save();
          
          // Broadcast old building update
          if (io) {
            io.emit('building-updated', {
              action: 'room-removed',
              buildingId: oldBuildingId,
              roomId: room._id,
              timestamp: new Date()
            });
          }
        }
      }
      
      // Update new building count
      if (newBuilding) {
        newBuilding.roomCount = await Room.countDocuments({ building: buildingId });
        await newBuilding.save();
        
        // Broadcast new building update
        if (io) {
          io.emit('building-updated', {
            action: 'room-added',
            buildingId: buildingId,
            roomId: room._id,
            timestamp: new Date()
          });
        }
      }
    } else {
      // Update current building count
      const currentBuilding = await Building.findById(room.building);
      if (currentBuilding) {
        currentBuilding.roomCount = await Room.countDocuments({ building: room.building });
        await currentBuilding.save();
      }
    }
    
    // **PERBAIKAN UTAMA: Broadcast room update melalui WebSocket**
    if (io) {
      broadcastRoomUpdate(io, room, 'updated', oldData);
      
      // Special handling for name changes
      if (name && name !== oldData.name) {
        console.log(`🔄 Room name changed: ${oldData.name} -> ${name}`);
        
        // Broadcast name change to all connected clients
        io.emit('room-name-changed', {
          roomId: room._id,
          oldName: oldData.name,
          newName: room.name,
          buildingName: room.buildingName,
          timestamp: new Date()
        });
      }
    }
    
    res.json({
      success: true,
      message: 'Room updated successfully',
      data: room,
      changes: {
        nameChanged: name && name !== oldData.name,
        buildingChanged: buildingChanged,
        dataSourceChanged: dataSource && dataSource !== oldData.dataSource,
        statusChanged: isActive !== undefined && isActive !== oldData.isActive
      }
    });
  } catch (error) {
    console.error('❌ Error updating room:', error);
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
    const io = req.app.get('socketio');
    const room = await Room.findById(req.params.id);
    
    if (!room) {
      return res.status(404).json({
        success: false,
        message: 'Room not found'
      });
    }
    
    const buildingId = room.building;
    const roomData = {
      id: room._id,
      name: room.name,
      buildingName: room.buildingName
    };
    
    await room.deleteOne();
    
    // Update building room count
    const building = await Building.findById(buildingId);
    if (building) {
      building.roomCount = await Room.countDocuments({ building: buildingId });
      await building.save();
      
      // Broadcast building update
      if (io) {
        io.emit('building-updated', {
          action: 'room-deleted',
          buildingId: buildingId,
          room: roomData,
          timestamp: new Date()
        });
      }
    }
    
    // **PERBAIKAN: Broadcast room deletion**
    if (io) {
      io.emit('room-deleted', {
        roomId: room._id,
        roomName: room.name,
        buildingName: room.buildingName,
        timestamp: new Date()
      });
      
      // Juga kirim ke channel spesifik room
      io.to(room._id.toString()).emit('room-updated', {
        action: 'deleted',
        room: roomData,
        timestamp: new Date()
      });
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

// PATCH: Update room status (aktif/nonaktif) dengan WebSocket
router.patch('/:id/status', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { isActive } = req.body;
    const io = req.app.get('socketio');
    
    const room = await Room.findById(req.params.id);
    
    if (!room) {
      return res.status(404).json({
        success: false,
        message: 'Room not found'
      });
    }
    
    const oldStatus = room.isActive;
    
    if (isActive !== undefined) {
      room.isActive = isActive;
      room.updatedAt = new Date();
      await room.save();
      
      // **PERBAIKAN: Broadcast status update**
      if (io) {
        io.emit('room-status-changed', {
          roomId: room._id,
          roomName: room.name,
          oldStatus: oldStatus,
          newStatus: isActive,
          buildingName: room.buildingName,
          timestamp: new Date()
        });
        
        io.to(room._id.toString()).emit('room-update', {
          roomId: room._id,
          data: {
            currentAQI: room.currentAQI,
            currentData: room.currentData,
            updatedAt: room.updatedAt,
            isActive: room.isActive
          },
          timestamp: new Date(),
          source: 'admin-status-change'
        });
      }
      
      res.json({
        success: true,
        message: `Room status updated to ${isActive ? 'active' : 'inactive'}`,
        data: room
      });
    } else {
      res.status(400).json({
        success: false,
        message: 'isActive field is required'
      });
    }
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error updating room status',
      error: error.message
    });
  }
});

// Utility endpoint: Sync all room building names
router.post('/sync-building-names', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const io = req.app.get('socketio');
    const rooms = await Room.find().populate('building', 'name');
    let updatedCount = 0;
    let updatedRooms = [];
    
    for (const room of rooms) {
      if (room.building && room.buildingName !== room.building.name) {
        const oldName = room.buildingName;
        room.buildingName = room.building.name;
        await room.save();
        updatedCount++;
        
        updatedRooms.push({
          id: room._id,
          oldName: oldName,
          newName: room.building.name
        });
        
        // Broadcast update untuk room yang di-sync
        if (io) {
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
        }
      }
    }
    
    res.json({
      success: true,
      message: `Building names synced for ${updatedCount} rooms`,
      updatedRooms: updatedRooms
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error syncing building names',
      error: error.message
    });
  }
});

module.exports = router;