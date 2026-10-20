const express = require('express');
const router = express.Router();

const {
  registerAdmin,
  login,
  getProfile,
  checkAdminRegistered,
  updateProfile,       
  changePassword 
} = require('../controllers/authController');

const { authMiddleware } = require('../middleware/authMiddleware');

// Public routes
router.get('/check-admin', checkAdminRegistered);
router.post('/register-admin', registerAdmin);
router.post('/login', login);
router.get('/profile', authMiddleware, getProfile);    

// Protected routes
router.get('/profile', authMiddleware, getProfile);
router.put('/profile', authMiddleware, updateProfile);             
router.put('/change-password', authMiddleware, changePassword);     

module.exports = router;