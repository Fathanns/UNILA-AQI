const express = require('express');
const router = express.Router();
const { seedSampleData, clearSampleData } = require('../utils/seedData');
const { authMiddleware, adminMiddleware } = require('../middleware/authMiddleware');
const SensorData = require('../models/SensorData');
const Room = require('../models/Room');

// Seed sample data (admin only)
router.post('/seed', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await seedSampleData();
    res.json(result);
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      message: 'Error seeding data',
      error: error.message 
    });
  }
});

// Clear sample data (admin only)
router.post('/clear', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await clearSampleData();
    res.json(result);
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      message: 'Error clearing data',
      error: error.message 
    });
  }
});


module.exports = router;