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

// Update profile (username & email)
const updateProfile = async (req, res) => {
  try {
    const { username, email } = req.body;

    if (!username || !username.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Username is required'
      });
    }

    const user = await User.findById(req.user.id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    // Cek username unik
    if (username.trim() !== user.username) {
      const existing = await User.findOne({
        username: username.trim(),
        _id: { $ne: user._id }
      });
      if (existing) {
        return res.status(400).json({
          success: false,
          message: 'Username already taken'
        });
      }
    }

    // Validasi format email (jika diisi)
    if (email && email.trim()) {
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailRegex.test(email.trim())) {
        return res.status(400).json({
          success: false,
          message: 'Invalid email format'
        });
      }
    }

    user.username = username.trim();
    if (email !== undefined) {
      user.email = email ? email.trim() : '';
    }

    await user.save();

    res.json({
      success: true,
      message: 'Profile updated successfully',
      user: {
        id: user._id,
        username: user.username,
        email: user.email,
        role: user.role
      }
    });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

// Change password
const changePassword = async (req, res) => {
  try {
    const { oldPassword, newPassword } = req.body;

    if (!oldPassword || !newPassword) {
      return res.status(400).json({
        success: false,
        message: 'Old and new password are required'
      });
    }

    if (newPassword.length < 8) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 8 characters'
      });
    }

    if (!/^(?=.*[a-zA-Z])(?=.*\d)/.test(newPassword)) {
      return res.status(400).json({
        success: false,
        message: 'Password must contain both letters and numbers'
      });
    }

    const user = await User.findById(req.user.id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    const isValid = await comparePassword(oldPassword, user.password);
    if (!isValid) {
      return res.status(401).json({
        success: false,
        message: 'Old password is incorrect'
      });
    }

    if (oldPassword === newPassword) {
      return res.status(400).json({
        success: false,
        message: 'New password must be different from old password'
      });
    }

    user.password = await hashPassword(newPassword);
    await user.save();

    res.json({
      success: true,
      message: 'Password changed successfully'
    });
  } catch (error) {
    console.error('Change password error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};



module.exports = {
  registerAdmin,
  login,
  getProfile,
  checkAdminRegistered,
  updateProfile,
  changePassword
};