const express = require('express');
const router = express.Router();
const IoTDevice = require('../models/IoTDevice');
const Building = require('../models/Building');
const { authMiddleware, adminMiddleware } = require('../middleware/authMiddleware');

// GET all IoT devices
router.get('/', authMiddleware, async (req, res) => {
  try {
    const devices = await IoTDevice.find()
      .populate('building', 'name code')
      .sort({ name: 1 });
    
    res.json({
      success: true,
      count: devices.length,
      data: devices
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching IoT devices',
      error: error.message
    });
  }
});

// GET single IoT device
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    const device = await IoTDevice.findById(req.params.id)
      .populate('building', 'name code');
    
    if (!device) {
      return res.status(404).json({
        success: false,
        message: 'IoT device not found'
      });
    }
    
    res.json({
      success: true,
      data: device
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching IoT device',
      error: error.message
    });
  }
});

// POST create IoT device (admin only)
router.post('/', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { name, description, buildingId, apiEndpoint, isActive } = req.body;
    
    // Validate required fields
    if (!name) {
      return res.status(400).json({
        success: false,
        message: 'Device name is required'
      });
    }
    
    if (!apiEndpoint) {
      return res.status(400).json({
        success: false,
        message: 'API endpoint is required'
      });
    }
    
    // Validate API endpoint format (basic URL validation)
    try {
      new URL(apiEndpoint);
    } catch (error) {
      return res.status(400).json({
        success: false,
        message: 'Invalid API endpoint URL format'
      });
    }
    
    let building = null;
    if (buildingId) {
      building = await Building.findById(buildingId);
      if (!building) {
        return res.status(404).json({
          success: false,
          message: 'Building not found'
        });
      }
    }
    
    // Check if device name already exists
    const existingDevice = await IoTDevice.findOne({ name: name.trim() });
    if (existingDevice) {
      return res.status(400).json({
        success: false,
        message: 'Device name already exists'
      });
    }
    
    const device = new IoTDevice({
      name: name.trim(),
      description: description?.trim(),
      building: buildingId,
      buildingName: building?.name,
      apiEndpoint: apiEndpoint.trim(),
      isActive: isActive !== undefined ? isActive : true,
      status: 'offline',
      createdAt: new Date(),
      updatedAt: new Date()
    });
    
    await device.save();
    
    res.status(201).json({
      success: true,
      message: 'IoT device created successfully',
      data: device
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error creating IoT device',
      error: error.message
    });
  }
});

// PUT update IoT device (admin only)
router.put('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { name, description, buildingId, apiEndpoint, isActive } = req.body;
    
    const device = await IoTDevice.findById(req.params.id);
    
    if (!device) {
      return res.status(404).json({
        success: false,
        message: 'IoT device not found'
      });
    }
    
    // Validate API endpoint format if provided
    if (apiEndpoint) {
      try {
        new URL(apiEndpoint);
      } catch (error) {
        return res.status(400).json({
          success: false,
          message: 'Invalid API endpoint URL format'
        });
      }
    }
    
    let building = null;
    if (buildingId && buildingId !== device.building?.toString()) {
      building = await Building.findById(buildingId);
      if (!building) {
        return res.status(404).json({
          success: false,
          message: 'Building not found'
        });
      }
    }
    
    // Check if new device name already exists (if changing)
    if (name && name !== device.name) {
      const existingDevice = await IoTDevice.findOne({ 
        name: name.trim(),
        _id: { $ne: device._id }
      });
      
      if (existingDevice) {
        return res.status(400).json({
          success: false,
          message: 'Device name already exists'
        });
      }
    }
    
    // Update fields
    if (name) device.name = name.trim();
    if (description !== undefined) device.description = description?.trim();
    if (buildingId !== undefined) {
      device.building = buildingId;
      device.buildingName = building?.name;
    }
    if (apiEndpoint) device.apiEndpoint = apiEndpoint.trim();
    if (isActive !== undefined) device.isActive = isActive;
    device.updatedAt = new Date();
    
    await device.save();
    
    res.json({
      success: true,
      message: 'IoT device updated successfully',
      data: device
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error updating IoT device',
      error: error.message
    });
  }
});

// DELETE IoT device (admin only)
router.delete('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const device = await IoTDevice.findById(req.params.id);
    
    if (!device) {
      return res.status(404).json({
        success: false,
        message: 'IoT device not found'
      });
    }
    
    // Check if device is being used by any room
    const Room = require('../models/Room');
    const roomCount = await Room.countDocuments({ iotDeviceId: device._id.toString() });
    
    if (roomCount > 0) {
      return res.status(400).json({
        success: false,
        message: 'Cannot delete device that is being used by rooms',
        roomCount: roomCount
      });
    }
    
    await device.deleteOne();
    
    res.json({
      success: true,
      message: 'IoT device deleted successfully'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error deleting IoT device',
      error: error.message
    });
  }
});

// PATCH update device status (for simulation or real IoT device)
router.patch('/:id/status', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { status, lastUpdate } = req.body;
    
    const device = await IoTDevice.findById(req.params.id);
    
    if (!device) {
      return res.status(404).json({
        success: false,
        message: 'IoT device not found'
      });
    }
    
    const validStatuses = ['online', 'offline', 'error'];
    if (status && !validStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid status. Must be online, offline, or error'
      });
    }
    
    if (status) device.status = status;
    if (lastUpdate) device.lastUpdate = new Date(lastUpdate);
    device.updatedAt = new Date();
    
    await device.save();
    
    res.json({
      success: true,
      message: 'Device status updated successfully',
      data: device
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error updating device status',
      error: error.message
    });
  }
});

module.exports = router;