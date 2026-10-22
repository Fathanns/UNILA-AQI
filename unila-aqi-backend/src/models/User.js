const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  username: {
    type: String,
    required: true,
    unique: true,
    trim: true
  },
  password: {
    type: String,
    required: true
  },
  role: {
    type: String,
    enum: ['admin', 'user'],
    default: 'user'
  },
  email: {
    type: String,
    trim: true,
    lowercase: true
  },
  pendingEmail: {
  type: String,
  trim: true,
  lowercase: true
},
emailChangeCode: {
  type: String
},
emailChangeCodeExpiry: {
  type: Date
},
  isActive: {
    type: Boolean,
    default: true
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  lastLogin: {
    type: Date
  },

  resetPasswordCode: { type: String },
  resetPasswordCodeExpiry: { type: Date },

});

module.exports = mongoose.model('User', userSchema);