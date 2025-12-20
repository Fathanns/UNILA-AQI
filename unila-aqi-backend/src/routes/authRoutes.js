const express = require('express');
const router = express.Router();
const {
  registerAdmin,
  login,
  getProfile,
  checkAdminRegistered
} = require('../controllers/authController');
const { authMiddleware } = require('../middleware/authMiddleware');

// Public routes
router.get('/check-admin', checkAdminRegistered);
router.post('/register-admin', registerAdmin);
router.post('/login', login);

// Protected routes
router.get('/profile', authMiddleware, getProfile);

module.exports = router;