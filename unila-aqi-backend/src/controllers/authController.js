const User = require('../models/User');
const { generateToken, hashPassword, comparePassword } = require('../utils/auth');
const {
  generateResetCode,
  sendResetCodeEmail,
  sendEmailChangeCodeEmail
} = require('../utils/emailService');

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

const requestEmailChangeCode = async (req, res) => {
  try {
    const { newEmail } = req.body;

    if (!newEmail || !newEmail.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Email baru wajib diisi'
      });
    }

    const email = newEmail.trim().toLowerCase();
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

    if (!emailRegex.test(email)) {
      return res.status(400).json({
        success: false,
        message: 'Format email tidak valid'
      });
    }

    const user = await User.findById(req.user.id);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    const currentEmail = (user.email || '').trim().toLowerCase();

    if (currentEmail === email) {
      return res.status(400).json({
        success: false,
        message: 'Email baru sama dengan email saat ini'
      });
    }

    const existingUser = await User.findOne({
      email,
      _id: { $ne: user._id }
    });

    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'Email sudah digunakan akun lain'
      });
    }

    const code = generateResetCode();
    const expiry = new Date(Date.now() + 15 * 60 * 1000);

    user.pendingEmail = email;
    user.emailChangeCode = code;
    user.emailChangeCodeExpiry = expiry;
    await user.save();

    try {
      await sendEmailChangeCodeEmail(email, code, user.username);
      console.log(`✅ Email change code sent to ${email}`);
    } catch (emailError) {
      console.error('❌ Email send error:', emailError);
      return res.status(500).json({
        success: false,
        message: 'Gagal mengirim email. Periksa koneksi server atau coba lagi.'
      });
    }

    res.json({
      success: true,
      message: 'Kode verifikasi telah dikirim ke email baru',
      email
    });
  } catch (error) {
    console.error('Request email change error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

// Update profile (username & email)
const updateProfile = async (req, res) => {
  try {
    const { username, email, emailChangeCode } = req.body;

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

    const currentEmail = (user.email || '').trim().toLowerCase();
    const requestedEmail = email !== undefined
      ? (email ? email.trim().toLowerCase() : '')
      : currentEmail;

    const emailChanged = requestedEmail !== currentEmail;

    // Validasi format email jika diisi
    if (requestedEmail) {
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailRegex.test(requestedEmail)) {
        return res.status(400).json({
          success: false,
          message: 'Invalid email format'
        });
      }
    }

    // Jika email berubah, wajib verifikasi kode
    if (emailChanged) {
      if (requestedEmail === '') {
        return res.status(400).json({
          success: false,
          message: 'Email baru wajib diisi'
        });
      }

      if (!emailChangeCode || !emailChangeCode.trim()) {
        return res.status(400).json({
          success: false,
          message: 'Kode verifikasi email wajib diisi'
        });
      }

      if (!user.pendingEmail || user.pendingEmail !== requestedEmail) {
        return res.status(400).json({
          success: false,
          message: 'Silakan minta kode verifikasi untuk email baru terlebih dahulu'
        });
      }

      if (!user.emailChangeCode || !user.emailChangeCodeExpiry) {
        return res.status(400).json({
          success: false,
          message: 'Kode verifikasi tidak ditemukan. Silakan minta kode baru.'
        });
      }

      if (new Date() > new Date(user.emailChangeCodeExpiry)) {
        return res.status(400).json({
          success: false,
          message: 'Kode verifikasi sudah kedaluwarsa. Silakan minta kode baru.'
        });
      }

      if (user.emailChangeCode !== emailChangeCode.trim()) {
        return res.status(400).json({
          success: false,
          message: 'Kode verifikasi salah'
        });
      }
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

    user.username = username.trim();

    if (emailChanged) {
      user.email = requestedEmail;

      // Bersihkan data verifikasi
      user.pendingEmail = undefined;
      user.emailChangeCode = undefined;
      user.emailChangeCodeExpiry = undefined;
    } else if (email !== undefined) {
      user.email = requestedEmail;
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

// ============ FITUR LUPA PASSWORD ============

// 1. Request reset password (kirim kode ke email)
const requestPasswordReset = async (req, res) => {
  try {
    const { email } = req.body;

    if (!email || !email.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Email wajib diisi',
      });
    }

    // Cari admin dengan email tersebut
    const user = await User.findOne({
      email: email.trim().toLowerCase(),
      role: 'admin',
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Email tidak terdaftar sebagai admin',
      });
    }

    // Generate kode 6-digit
    const code = generateResetCode();
    const expiry = new Date(Date.now() + 15 * 60 * 1000); // 15 menit

    user.resetPasswordCode = code;
    user.resetPasswordCodeExpiry = expiry;
    await user.save();

    // Kirim email
    try {
      await sendResetCodeEmail(user.email, code, user.username);
      console.log(`✅ Reset code sent to ${user.email}`);
    } catch (emailError) {
      console.error('❌ Email send error:', emailError);
      return res.status(500).json({
        success: false,
        message: 'Gagal mengirim email. Periksa koneksi server atau coba lagi.',
      });
    }

    res.json({
      success: true,
      message: 'Kode verifikasi telah dikirim ke email Anda',
      email: user.email,
    });
  } catch (error) {
    console.error('Request password reset error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message,
    });
  }
};

// 2. Reset password dengan kode verifikasi
const resetPasswordWithCode = async (req, res) => {
  try {
    const { email, code, newPassword } = req.body;

    if (!email || !code || !newPassword) {
      return res.status(400).json({
        success: false,
        message: 'Email, kode, dan password baru wajib diisi',
      });
    }

    if (newPassword.length < 8) {
      return res.status(400).json({
        success: false,
        message: 'Password minimal 8 karakter',
      });
    }

    if (!/^(?=.*[a-zA-Z])(?=.*\d)/.test(newPassword)) {
      return res.status(400).json({
        success: false,
        message: 'Password harus mengandung huruf dan angka',
      });
    }

    const user = await User.findOne({
      email: email.trim().toLowerCase(),
      role: 'admin',
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Email tidak terdaftar sebagai admin',
      });
    }

    if (!user.resetPasswordCode || !user.resetPasswordCodeExpiry) {
      return res.status(400).json({
        success: false,
        message: 'Kode verifikasi tidak ditemukan. Silakan minta kode baru.',
      });
    }

    if (new Date() > new Date(user.resetPasswordCodeExpiry)) {
      return res.status(400).json({
        success: false,
        message: 'Kode sudah kedaluwarsa. Silakan minta kode baru.',
      });
    }

    if (user.resetPasswordCode !== code.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Kode verifikasi salah',
      });
    }

    // Update password
    user.password = await hashPassword(newPassword);
    user.resetPasswordCode = undefined;
    user.resetPasswordCodeExpiry = undefined;
    await user.save();

    res.json({
      success: true,
      message: 'Password berhasil direset',
    });
  } catch (error) {
    console.error('Reset password error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message,
    });
  }
};

// 3. Kirim ulang kode
const resendResetCode = async (req, res) => {
  try {
    const { email } = req.body;

    if (!email || !email.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Email wajib diisi',
      });
    }

    const user = await User.findOne({
      email: email.trim().toLowerCase(),
      role: 'admin',
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Email tidak terdaftar sebagai admin',
      });
    }

    // Generate kode baru
    const code = generateResetCode();
    const expiry = new Date(Date.now() + 15 * 60 * 1000);

    user.resetPasswordCode = code;
    user.resetPasswordCodeExpiry = expiry;
    await user.save();

    try {
      await sendResetCodeEmail(user.email, code, user.username);
      console.log(`✅ Reset code resent to ${user.email}`);
    } catch (emailError) {
      console.error('❌ Email send error:', emailError);
      return res.status(500).json({
        success: false,
        message: 'Gagal mengirim email. Coba lagi nanti.',
      });
    }

    res.json({
      success: true,
      message: 'Kode verifikasi baru telah dikirim ke email',
    });
  } catch (error) {
    console.error('Resend code error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message,
    });
  }
};



module.exports = {
  registerAdmin,
  login,
  getProfile,
  checkAdminRegistered,
  updateProfile,
  changePassword,
  requestPasswordReset,
  resetPasswordWithCode,
  resendResetCode,
  requestEmailChangeCode,
};