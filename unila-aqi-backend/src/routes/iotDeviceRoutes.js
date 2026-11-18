const express = require('express');
const router = express.Router();
const IoTDevice = require('../models/IoTDevice');
const { authMiddleware, adminMiddleware } = require('../middleware/authMiddleware');

// GET all IoT devices
router.get('/', authMiddleware, async (req, res) => {
  try {
    const live = req.query.live === 'true';

    let devices = await IoTDevice.find().sort({ name: 1 });

    // ✅ Bila ?live=true → lakukan quick-check status online/offline
    // sebelum mengembalikan data, sehingga status di frontend selalu fresh.
    if (live && devices.length > 0) {
      try {
        const iotService = require('../services/iotService');
        await iotService.checkDeviceStatus(devices);

        // Re-fetch untuk dapat status yang sudah di-update
        devices = await IoTDevice.find().sort({ name: 1 });
      } catch (checkErr) {
        console.warn('⚠️ Live status check failed:', checkErr.message);
        // Tetap lanjut dengan data cached bila check gagal
      }
    }

    res.json({
      success: true,
      count: devices.length,
      data: devices
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Terjadi kesalahan ketika mengambil data device iot',
      error: error.message
    });
  }
});

// GET single IoT device
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    const device = await IoTDevice.findById(req.params.id);

    if (!device) {
      return res.status(404).json({
        success: false,
        message: 'Device IoT tidak ditemukan'
      });
    }

    res.json({
      success: true,
      data: device
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Terjadi kesalahan ketika mengambil data device iot',
      error: error.message
    });
  }
});

// POST create IoT device (admin only)
router.post('/', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { name, description, apiEndpoint } = req.body;

    if (!name) {
      return res.status(400).json({
        success: false,
        message: 'Nama device diperlukan'
      });
    }

    if (!apiEndpoint) {
      return res.status(400).json({
        success: false,
        message: 'API endpoint dibutuhkan untuk device IoT'
      });
    }

    try {
      new URL(apiEndpoint);
    } catch (error) {
      return res.status(400).json({
        success: false,
        message: 'Format URL API endpoint tidak valid'
      });
    }

    const existingDevice = await IoTDevice.findOne({ name: name.trim() });
    if (existingDevice) {
      return res.status(400).json({
        success: false,
        message: 'Nama Device ini sudah ada, silahkan ganti nama lain'
      });
    }

    const device = new IoTDevice({
      name: name.trim(),
      description: description?.trim(),
      apiEndpoint: apiEndpoint.trim(),
      status: 'offline',
      createdAt: new Date(),
      updatedAt: new Date()
    });

    await device.save();

    res.status(201).json({
      success: true,
      message: 'Device iot berhasil dibuat',
      data: device
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Terjadi kesalahan ketika membuat device iot',
      error: error.message
    });
  }
});

// PUT update IoT device (admin only)
router.put('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { name, description, apiEndpoint } = req.body;

    const device = await IoTDevice.findById(req.params.id);

    if (!device) {
      return res.status(404).json({
        success: false,
        message: 'Device IoT tidak ditemukan'
      });
    }

    if (apiEndpoint) {
      try {
        new URL(apiEndpoint);
      } catch (error) {
        return res.status(400).json({
          success: false,
          message: 'Format URL API endpoint tidak valid'
        });
      }
    }

    if (name && name !== device.name) {
      const existingDevice = await IoTDevice.findOne({
        name: name.trim(),
        _id: { $ne: device._id }
      });

      if (existingDevice) {
        return res.status(400).json({
          success: false,
          message: 'Nama Device ini sudah ada, silahkan ganti nama lain'
        });
      }
    }

    if (name) device.name = name.trim();
    if (description !== undefined) device.description = description?.trim();
    if (apiEndpoint) device.apiEndpoint = apiEndpoint.trim();
    device.updatedAt = new Date();

    await device.save();

    res.json({
      success: true,
      message: 'Device iot berhasil diupdate',
      data: device
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Terjadi kesalahan ketika mengupdate device iot',
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
        message: 'Device IoT tidak ditemukan'
      });
    }

    const Room = require('../models/Room');
    const roomCount = await Room.countDocuments({ iotDeviceId: device._id.toString() });

    if (roomCount > 0) {
      return res.status(400).json({
        success: false,
        message: 'Tidak bisa menghapus device yang masih digunakan di room. Silahkan hapus room yang menggunakan device ini terlebih dahulu.',
        roomCount: roomCount
      });
    }

    await device.deleteOne();

    res.json({
      success: true,
      message: 'Device iot berhasil dihapus',
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Terjadi kesalahan ketika menghapus device iot',
      error: error.message
    });
  }
});

// PATCH update device status
router.patch('/:id/status', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { status, lastUpdate } = req.body;

    const device = await IoTDevice.findById(req.params.id);

    if (!device) {
      return res.status(404).json({
        success: false,
        message: 'Device IoT tidak ditemukan'
      });
    }

    const validStatuses = ['online', 'offline'];
    if (status && !validStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid status. Must be online or offline'
      });
    }

    if (status) device.status = status;
    if (lastUpdate) device.lastUpdate = new Date(lastUpdate);
    device.updatedAt = new Date();

    await device.save();

    res.json({
      success: true,
      message: 'Status device berhasil diupdate',
      data: device
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Terjadi kesalahan ketika mengupdate status device',
      error: error.message
    });
  }
});


router.post('/force-poll', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const iotService = require('../services/iotService');
    const result = await iotService.forcePollAll();

    res.json({
      success: true,
      message: 'Force polling initiated',
      ...result
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Terjadi kesalahan ketika memaksa polling',
      error: error.message
    });
  }
});

router.get('/service/status', authMiddleware, async (req, res) => {
  try {
    const iotService = require('../services/iotService');

    const iotStatus = iotService.getStatus();

    res.json({
      success: true,
      data: {
        iot: iotStatus,
        summary: {
          iotRunning: iotStatus.isRunning,
          totalServices: iotStatus.isRunning ? 1 : 0
        }
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Terjadi kesalahan ketika mengambil status service',
      error: error.message
    });
  }
});

module.exports = router;