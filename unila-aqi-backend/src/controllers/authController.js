const User = require('../models/User');
const { generateToken, hashPassword, comparePassword } = require('../utils/auth');

// Register admin (untuk pertama kali)
const registerAdmin = async (req, res) => {
  try {
    const { username, password, email } = req.body;

    // Check if admin already exists
    const existingAdmin = await User.findOne({ role: 'admin' });
    if (existingAdmin) {
      return res.status(400).json({
        success: false,
        message: 'Admin already registered'
      });
    }

    // Create new admin
    const hashedPassword = await hashPassword(password);
    
    const admin = new User({
      username,
      password: hashedPassword,
      email,
      role: 'admin'
    });

    await admin.save();

    // Generate token
    const token = generateToken(admin._id, admin.username, admin.role);

    res.status(201).json({
      success: true,
      message: 'Admin registered successfully',
      token,
      user: {
        id: admin._id,
        username: admin.username,
        role: admin.role,
        email: admin.email
      }
    });

  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

// Login
const login = async (req, res) => {
  try {
    const { username, password, role } = req.body;

    // Find user
    const user = await User.findOne({ username });
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }

    // Check if user is active
    if (!user.isActive) {
      return res.status(403).json({
        success: false,
        message: 'Account is disabled'
      });
    }

    // Check role (admin harus login sebagai admin, user sebagai user)
    if (role && user.role !== role) {
      return res.status(401).json({
        success: false,
        message: 'Invalid role selection'
      });
    }

    // Verify password
    const isPasswordValid = await comparePassword(password, user.password);
    if (!isPasswordValid) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }

    // Update last login
    user.lastLogin = new Date();
    await user.save();

    // Generate token
    const token = generateToken(user._id, user.username, user.role);

    res.json({
      success: true,
      message: 'Login successful',
      token,
      user: {
        id: user._id,
        username: user.username,
        role: user.role,
        email: user.email
      }
    });

  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

// Get current user profile
const getProfile = async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select('-password');
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    res.json({
      success: true,
      user
    });

  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
};

// Check if admin is registered (untuk frontend)
const checkAdminRegistered = async (req, res) => {
  try {
    const admin = await User.findOne({ role: 'admin' });
    
    res.json({
      success: true,
      isRegistered: !!admin
    });

  } catch (error) {
    console.error('Check admin error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
};

module.exports = {
  registerAdmin,
  login,
  getProfile,
  checkAdminRegistered
};