// File: src/routes/roomRoutes.js
const express = require('express');
const router = express.Router();
const Room = require('../models/Room');
const Building = require('../models/Building');
const { authMiddleware, adminMiddleware } = require('../middleware/authMiddleware');

// Helper untuk broadcast room update - DIPERBAIKI LENGKAP
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
    
    // 🔥 PERBAIKAN UTAMA: Broadcast perubahan spesifik jika ada
    if (oldData) {
      // Jika nama berubah
      if (oldData.name !== room.name) {
        console.log(`🔄 Broadcasting room name change: ${oldData.name} -> ${room.name}`);
        
        io.emit('room-name-changed', {
          roomId: room._id,
          oldName: oldData.name,
          newName: room.name,
          buildingName: room.buildingName,
          timestamp: new Date()
        });
        
        // Juga broadcast ke channel spesifik room
        io.to(room._id.toString()).emit('room-name-updated', {
          roomId: room._id,
          oldName: oldData.name,
          newName: room.name,
          buildingName: room.buildingName,
          timestamp: new Date()
        });
      }
      
      // Jika building berubah
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
      
      // Jika status aktif berubah
      if (oldData.isActive !== room.isActive) {
        io.emit('room-status-changed', {
          roomId: room._id,
          oldStatus: oldData.isActive,
          newStatus: room.isActive,
          roomName: room.name,
          buildingName: room.buildingName,
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
    
    // 🔥 PERBAIKAN: Broadcast room creation
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

// PUT update room (admin only) - PERBAIKAN UTAMA LENGKAP
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
    
    // 🔥 SIMPAN DATA LAMA UNTUK PERBANDINGAN
    const oldData = {
      name: room.name,
      buildingId: room.building._id ? room.building._id.toString() : room.building.toString(),
      buildingName: room.buildingName,
      dataSource: room.dataSource,
      isActive: room.isActive,
      iotDeviceId: room.iotDeviceId
    };
    
    console.log(`🔄 Room update request for: ${room.name}`);
    console.log(`   Old data:`, oldData);
    console.log(`   New data:`, { name, buildingId, dataSource, iotDeviceId, isActive });
    
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
      console.log(`   Building changed: ${oldData.buildingName} -> ${newBuilding.name}`);
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
    if (name) {
      console.log(`   Name changed: ${room.name} -> ${name}`);
      room.name = name.trim();
    }
    if (dataSource !== undefined) {
      console.log(`   Data source changed: ${room.dataSource} -> ${dataSource}`);
      room.dataSource = dataSource;
      room.iotDeviceId = dataSource === 'iot' ? iotDeviceId : null;
    }
    if (iotDeviceId !== undefined && dataSource === 'iot') {
      room.iotDeviceId = iotDeviceId;
    }
    if (isActive !== undefined) {
      console.log(`   Status changed: ${room.isActive} -> ${isActive}`);
      room.isActive = isActive;
    }
    room.updatedAt = new Date();
    
    // If building didn't change, ensure buildingName is synced
    if (!buildingChanged) {
      const currentBuilding = await Building.findById(room.building);
      if (currentBuilding && room.buildingName !== currentBuilding.name) {
        console.log(`   Syncing building name: ${room.buildingName} -> ${currentBuilding.name}`);
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
              roomName: room.name,
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
            roomName: room.name,
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
    
    // 🔥 PERBAIKAN UTAMA: Broadcast room update melalui WebSocket
    if (io) {
      console.log(`📢 Broadcasting room update via WebSocket...`);
      broadcastRoomUpdate(io, room, 'updated', oldData);
      
      // Special handling for name changes
      if (name && name !== oldData.name) {
        console.log(`   🚀 Sending room-name-changed event`);
        
        // Additional broadcast for immediate UI update
        io.emit('room-name-changed-immediate', {
          roomId: room._id,
          oldName: oldData.name,
          newName: room.name,
          buildingName: room.buildingName,
          timestamp: new Date()
        });
      }
    }
    
    // Log perubahan
    const changes = {
      nameChanged: name && name !== oldData.name,
      buildingChanged: buildingChanged,
      dataSourceChanged: dataSource && dataSource !== oldData.dataSource,
      statusChanged: isActive !== undefined && isActive !== oldData.isActive
    };
    
    console.log(`✅ Room updated successfully. Changes:`, changes);
    
    res.json({
      success: true,
      message: 'Room updated successfully',
      data: room,
      changes: changes
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
    
    // Broadcast room deletion
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

// 🔥 BARU: Endpoint untuk force refresh room data
router.post('/:id/force-refresh', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const io = req.app.get('socketio');
    const room = await Room.findById(req.params.id);
    
    if (!room) {
      return res.status(404).json({
        success: false,
        message: 'Room not found'
      });
    }
    
    if (io) {
      // Broadcast refresh event
      io.emit('room-force-refresh', {
        roomId: room._id,
        roomName: room.name,
        timestamp: new Date()
      });
      
      io.to(room._id.toString()).emit('room-refresh-requested', {
        timestamp: new Date()
      });
    }
    
    res.json({
      success: true,
      message: 'Force refresh broadcasted',
      roomId: room._id,
      roomName: room.name
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error forcing refresh',
      error: error.message
    });
  }
});

// 🔥 BARU: Endpoint untuk sync room dengan building name
router.post('/:id/sync-building', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const io = req.app.get('socketio');
    const room = await Room.findById(req.params.id).populate('building', 'name');
    
    if (!room) {
      return res.status(404).json({
        success: false,
        message: 'Room not found'
      });
    }
    
    const oldBuildingName = room.buildingName;
    const newBuildingName = room.building.name;
    
    if (oldBuildingName !== newBuildingName) {
      room.buildingName = newBuildingName;
      room.updatedAt = new Date();
      await room.save();
      
      // Broadcast update
      if (io) {
        io.emit('room-building-synced', {
          roomId: room._id,
          oldBuildingName: oldBuildingName,
          newBuildingName: newBuildingName,
          timestamp: new Date()
        });
      }
      
      res.json({
        success: true,
        message: 'Building name synced',
        oldBuildingName,
        newBuildingName
      });
    } else {
      res.json({
        success: true,
        message: 'Building name already synced',
        buildingName: newBuildingName
      });
    }
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error syncing building name',
      error: error.message
    });
  }
});

module.exports = router;