const express = require('express');
const router = express.Router();
const Building = require('../models/Building');
const Room = require('../models/Room');
const { authMiddleware, adminMiddleware } = require('../middleware/authMiddleware');

// GET all buildings (public)
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
      message: 'Gagal memuat data gedung'
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
        message: 'Gedung tidak ditemukan'
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
      message: 'Gagal memuat data gedung'
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
        message: 'Nama gedung wajib diisi'
      });
    }

    // Cek duplikat code HANYA jika code diisi
    if (code && code.trim()) {
      const existingCode = await Building.findOne({
        code: code.toUpperCase().trim()
      });
      if (existingCode) {
        return res.status(400).json({
          success: false,
          message: 'Kode gedung sudah digunakan. Gunakan kode lain atau kosongkan.'
        });
      }
    }

    // ✅ FIX: jangan set field `code` sama sekali jika kosong
    const buildingData = {
      name: name.trim(),
      roomCount: 0,
      createdAt: new Date(),
      updatedAt: new Date()
    };

    if (code && code.trim()) {
      buildingData.code = code.toUpperCase().trim();
    }
    if (description && description.trim()) {
      buildingData.description = description.trim();
    }

    const building = new Building(buildingData);
    await building.save();

    res.status(201).json({
      success: true,
      message: 'Gedung berhasil dibuat',
      data: building
    });
  } catch (error) {
    console.error('Error creating building:', error);

    if (error.code === 11000) {
      const dupField = Object.keys(error.keyPattern || {})[0];
      return res.status(400).json({
        success: false,
        message: dupField === 'code'
          ? 'Kode gedung sudah digunakan. Gunakan kode lain atau kosongkan.'
          : 'Data gedung sudah ada'
      });
    }

    res.status(500).json({
      success: false,
      message: 'Gagal membuat gedung. Silakan coba lagi.'
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
        message: 'Gedung tidak ditemukan'
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
          message: 'Kode gedung sudah digunakan. Gunakan kode lain atau kosongkan.'
        });
      }
    }

    if (name && name.trim()) building.name = name.trim();

    if (code !== undefined) {
      if (code && code.trim()) {
        building.code = code.toUpperCase().trim();
      } else {
        // ✅ FIX: benar-benar unset field agar tidak tersimpan sebagai `null`
        building.set('code', undefined);
      }
    }

    if (description !== undefined) {
      building.description = description && description.trim()
        ? description.trim()
        : undefined;
    }
    building.updatedAt = new Date();

    await building.save();

    // Sinkronkan buildingName di semua Room terkait saat nama berubah
    if (oldName !== building.name) {
      await Room.updateMany(
        { building: building._id },
        { $set: { buildingName: building.name } }
      );
    }

    res.json({
      success: true,
      message: 'Gedung berhasil diperbarui',
      data: building
    });
  } catch (error) {
    console.error('Error updating building:', error);

    if (error.code === 11000) {
      const dupField = Object.keys(error.keyPattern || {})[0];
      return res.status(400).json({
        success: false,
        message: dupField === 'code'
          ? 'Kode gedung sudah digunakan. Gunakan kode lain atau kosongkan.'
          : 'Data gedung sudah ada'
      });
    }

    res.status(500).json({
      success: false,
      message: 'Gagal memperbarui gedung. Silakan coba lagi.'
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
        message: 'Gedung tidak ditemukan'
      });
    }

    // Cegah hapus gedung yang masih memiliki ruangan
    const roomCount = await Room.countDocuments({ building: building._id });
    if (roomCount > 0) {
      return res.status(400).json({
        success: false,
        message: `Gedung tidak dapat dihapus karena masih memiliki ${roomCount} ruangan`
      });
    }

    await building.deleteOne();

    res.json({
      success: true,
      message: 'Gedung berhasil dihapus'
    });
  } catch (error) {
    console.error('Error deleting building:', error);
    res.status(500).json({
      success: false,
      message: 'Gagal menghapus gedung. Silakan coba lagi.'
    });
  }
});

module.exports = router;