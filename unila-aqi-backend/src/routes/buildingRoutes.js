const express = require('express');
const router = express.Router();
const Building = require('../models/Building');
const Room = require('../models/Room');
const { authMiddleware, adminMiddleware } = require('../middleware/authMiddleware');

// GET all buildings (public — dipakai dashboard pengunjung)
router.get('/', async (req, res) => {
  try {
    const buildings = await Building.find().sort({ name: 1 });

    res.json({
      success: true,
      count: buildings.length,
      data: buildings
    });
  } catch (error) {
    console.error('Error fetching buildings:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching buildings',
      error: error.message
    });
  }
});

// GET single building (public)
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
    console.error('Error fetching building:', error);
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

    if (!name || !name.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Building name is required'
      });
    }

    // Cek duplikat code jika diisi
    if (code && code.trim()) {
      const existingCode = await Building.findOne({
        code: code.toUpperCase().trim()
      });
      if (existingCode) {
        return res.status(400).json({
          success: false,
          message: 'Building code already exists'
        });
      }
    }

    const building = new Building({
      name: name.trim(),
      code: code && code.trim() ? code.toUpperCase().trim() : undefined,
      description: description && description.trim() ? description.trim() : undefined,
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
    console.error('Error creating building:', error);

    // Handle duplicate key dari unique index (code)
    if (error.code === 11000) {
      return res.status(400).json({
        success: false,
        message: 'Building code already exists'
      });
    }

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

    const oldName = building.name;

    // Cek duplikat code jika berubah
    if (code && code.trim() && code.toUpperCase().trim() !== building.code) {
      const existing = await Building.findOne({
        code: code.toUpperCase().trim(),
        _id: { $ne: building._id }
      });
      if (existing) {
        return res.status(400).json({
          success: false,
          message: 'Building code already exists'
        });
      }
    }

    if (name && name.trim()) building.name = name.trim();
    if (code !== undefined) {
      building.code = code && code.trim() ? code.toUpperCase().trim() : undefined;
    }
    if (description !== undefined) {
      building.description = description && description.trim() ? description.trim() : undefined;
    }
    building.updatedAt = new Date();

    await building.save();

    // FIXED: sinkronkan buildingName di semua Room terkait saat nama berubah
    if (oldName !== building.name) {
      await Room.updateMany(
        { building: building._id },
        { $set: { buildingName: building.name } }
      );
    }

    res.json({
      success: true,
      message: 'Building updated successfully',
      data: building
    });
  } catch (error) {
    console.error('Error updating building:', error);

    if (error.code === 11000) {
      return res.status(400).json({
        success: false,
        message: 'Building code already exists'
      });
    }

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
    const building = await Building.findById(req.params.id);
    if (!building) {
      return res.status(404).json({
        success: false,
        message: 'Building not found'
      });
    }

    // Cegah hapus gedung yang masih memiliki ruangan
    const roomCount = await Room.countDocuments({ building: building._id });
    if (roomCount > 0) {
      return res.status(400).json({
        success: false,
        message: 'Cannot delete building that has rooms',
        roomCount: roomCount
      });
    }

    await building.deleteOne();

    res.json({
      success: true,
      message: 'Building deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting building:', error);
    res.status(500).json({
      success: false,
      message: 'Error deleting building',
      error: error.message
    });
  }
});

module.exports = router;