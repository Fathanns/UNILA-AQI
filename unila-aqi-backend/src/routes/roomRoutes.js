const express = require('express');
const router = express.Router();
const Room = require('../models/Room');
const Building = require('../models/Building');
const { authMiddleware, adminMiddleware } = require('../middleware/authMiddleware');

const broadcastRoomUpdate = (io, room, action, oldData = null) => {
  if (io) {
    const updateData = {
      action: action,
      room: {
        id: room._id,
        name: room.name,
        buildingId: room.building,
        buildingName: room.buildingName,
        dataSource: room.dataSource,
        iotDeviceId: room.iotDeviceId,
        currentAQI: room.currentAQI,
        currentData: room.currentData,
        createdAt: room.createdAt,
        updatedAt: room.updatedAt
      },
      oldData: oldData,
      timestamp: new Date()
    };

    io.to(room._id.toString()).emit('room-updated', updateData);
    io.emit('dashboard-room-updated', updateData);

    if (oldData) {
      if (oldData.name !== room.name) {
        console.log(`🔄 Broadcasting room name change: ${oldData.name} -> ${room.name}`);

        io.emit('room-name-changed', {
          roomId: room._id,
          oldName: oldData.name,
          newName: room.name,
          buildingName: room.buildingName,
          timestamp: new Date()
        });

        io.to(room._id.toString()).emit('room-name-updated', {
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
    const { name, buildingId, dataSource, iotDeviceId } = req.body;
    const io = req.app.get('socketio');

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

    const building = await Building.findById(buildingId);
    if (!building) {
      return res.status(404).json({
        success: false,
        message: 'Building not found'
      });
    }

    const validDataSources = ['simulation', 'iot'];
    if (dataSource && !validDataSources.includes(dataSource)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid data source. Must be "simulation" or "iot"'
      });
    }

    if (dataSource === 'iot' && !iotDeviceId) {
      return res.status(400).json({
        success: false,
        message: 'IoT Device ID is required for IoT data source'
      });
    }

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

    building.roomCount = await Room.countDocuments({ building: buildingId });
    await building.save();

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

// PUT update room (admin only)
router.put('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { name, buildingId, dataSource, iotDeviceId } = req.body;
    const io = req.app.get('socketio');

    const room = await Room.findById(req.params.id)
      .populate('building', 'name');

    if (!room) {
      return res.status(404).json({
        success: false,
        message: 'Room not found'
      });
    }

    const oldData = {
      name: room.name,
      buildingId: room.building._id ? room.building._id.toString() : room.building.toString(),
      buildingName: room.buildingName,
      dataSource: room.dataSource,
      iotDeviceId: room.iotDeviceId || null
    };

    console.log(`🔄 Room update request for: ${room.name}`);

    const validDataSources = ['simulation', 'iot'];
    if (dataSource && !validDataSources.includes(dataSource)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid data source. Must be "simulation" or "iot"'
      });
    }

    if (dataSource === 'iot' && !iotDeviceId) {
      return res.status(400).json({
        success: false,
        message: 'IoT Device ID is required for IoT data source'
      });
    }

    let buildingChanged = false;
    let oldBuildingId = null;
    let newBuilding = null;

    if (buildingId && buildingId !== room.building.toString()) {
      newBuilding = await Building.findById(buildingId);
      if (!newBuilding) {
        return res.status(404).json({
          success: false,
          message: 'Building not found'
        });
      }

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

    if (name) {
      room.name = name.trim();
    }

    // ============================================================
    // FIXED: deteksi perubahan data source / device SEBELUM diubah
    // ============================================================
    const prevDataSource = oldData.dataSource;
    const prevIotDeviceId = oldData.iotDeviceId || null;

    if (dataSource !== undefined) {
      room.dataSource = dataSource;
      room.iotDeviceId = dataSource === 'iot' ? iotDeviceId : null;
    }
    if (iotDeviceId !== undefined && dataSource === 'iot') {
      room.iotDeviceId = iotDeviceId;
    }
    room.updatedAt = new Date();

    const deviceChanged =
      (prevDataSource !== room.dataSource) ||
      (prevIotDeviceId !== (room.iotDeviceId || null));

    // FIXED: reset data partikel supaya UI tidak menampilkan angka device LAMA
    // saat admin mengganti device. Data baru akan diisi oleh force-fetch di bawah.
    if (deviceChanged) {
      room.currentAQI = 0;
      room.currentData = {
        pm25: 0,
        pm10: 0,
        co2: 0,
        temperature: 0,
        humidity: 0,
        updatedAt: new Date()
      };
      console.log(
        `🔄 Room "${room.name}" device changed (${prevIotDeviceId} → ${room.iotDeviceId}). Data partikel direset.`
      );
    }

    if (!buildingChanged) {
      const currentBuilding = await Building.findById(room.building);
      if (currentBuilding && room.buildingName !== currentBuilding.name) {
        room.buildingName = currentBuilding.name;
      }
    }

    await room.save();

    // ============================================================
    // FIXED: jika device berubah & sekarang mode IoT → force-fetch data
    // fresh dari device baru SEKARANG juga, sebelum response dikirim.
    // ============================================================
    let deviceFetchStatus = null;

    if (deviceChanged && room.dataSource === 'iot' && room.iotDeviceId) {
      try {
        const iotService = require('../services/iotService');
        const fetchResult = await iotService.forceUpdateRoom(
          room._id.toString()
        );

        if (fetchResult.success) {
          deviceFetchStatus = 'success';

          // Re-fetch dari DB supaya object `room` di memori ikut terbarui
          const refreshed = await Room.findById(room._id)
            .populate('building', 'name');

          if (refreshed) {
            room.currentAQI = refreshed.currentAQI;
            room.currentData = refreshed.currentData;
            room.updatedAt = refreshed.updatedAt;
          }

          console.log(
            `✅ Device baru langsung fetch: AQI ${room.currentAQI}`
          );
        } else {
          deviceFetchStatus = 'failed';
          console.warn(
            `⚠️  Force-fetch device baru gagal: ${fetchResult.message}. Data akan diupdate pada poll berikutnya.`
          );
        }
      } catch (iotError) {
        deviceFetchStatus = 'error';
        console.error(
          '⚠️  Error force-fetch device baru:',
          iotError.message
        );
      }
    }

    if (buildingChanged) {
      if (oldBuildingId) {
        const oldBuilding = await Building.findById(oldBuildingId);
        if (oldBuilding) {
          oldBuilding.roomCount = await Room.countDocuments({
            building: oldBuildingId
          });
          await oldBuilding.save();

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

      if (newBuilding) {
        newBuilding.roomCount = await Room.countDocuments({
          building: buildingId
        });
        await newBuilding.save();

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
      const currentBuilding = await Building.findById(room.building);
      if (currentBuilding) {
        currentBuilding.roomCount = await Room.countDocuments({
          building: room.building
        });
        await currentBuilding.save();
      }
    }

    if (io) {
      broadcastRoomUpdate(io, room, 'updated', oldData);

      if (name && name !== oldData.name) {
        io.emit('room-name-changed-immediate', {
          roomId: room._id,
          oldName: oldData.name,
          newName: room.name,
          buildingName: room.buildingName,
          timestamp: new Date()
        });
      }
    }

    // FIXED: tambah deviceChanged & deviceFetchStatus ke response `changes`
    const changes = {
      nameChanged: name && name !== oldData.name,
      buildingChanged: buildingChanged,
      dataSourceChanged: dataSource && dataSource !== oldData.dataSource,
      deviceChanged: deviceChanged,
      deviceFetchStatus: deviceFetchStatus
    };

    // FIXED: pesan response menyesuaikan status force-fetch
    let responseMessage = 'Room updated successfully';
    if (deviceChanged && room.dataSource === 'iot') {
      if (deviceFetchStatus === 'success') {
        responseMessage =
          'Room updated & data partikel device baru berhasil dimuat.';
      } else if (
        deviceFetchStatus === 'failed' ||
        deviceFetchStatus === 'error'
      ) {
        responseMessage =
          'Room updated. Data partikel akan dimuat pada poll berikutnya karena device baru tidak merespons.';
      } else {
        responseMessage = 'Room updated.';
      }
    }

    res.json({
      success: true,
      message: responseMessage,
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

    const building = await Building.findById(buildingId);
    if (building) {
      building.roomCount = await Room.countDocuments({ building: buildingId });
      await building.save();

      if (io) {
        io.emit('building-updated', {
          action: 'room-deleted',
          buildingId: buildingId,
          room: roomData,
          timestamp: new Date()
        });
      }
    }

    if (io) {
      io.emit('room-deleted', {
        roomId: room._id,
        roomName: room.name,
        buildingName: room.buildingName,
        timestamp: new Date()
      });

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

// Force refresh
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

// Sync building name
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