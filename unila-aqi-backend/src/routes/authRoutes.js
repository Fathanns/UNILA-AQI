const express = require('express');
const router = express.Router();

const {
  registerAdmin,
  login,
  getProfile,
  checkAdminRegistered,
  updateProfile,       
  changePassword,
  requestPasswordReset,
  resetPasswordWithCode,
  resendResetCode,
} = require('../controllers/authController');

const { authMiddleware } = require('../middleware/authMiddleware');

// Public routes
router.get('/check-admin', checkAdminRegistered);
router.post('/register-admin', registerAdmin);
router.post('/login', login);
router.get('/profile', authMiddleware, getProfile);  

router.post('/forgot-password', requestPasswordReset);
router.post('/reset-password', resetPasswordWithCode);
router.post('/resend-reset-code', resendResetCode);

// Protected routes
router.get('/profile', authMiddleware, getProfile);
router.put('/profile', authMiddleware, updateProfile);             
router.put('/change-password', authMiddleware, changePassword);     

module.exports = router;