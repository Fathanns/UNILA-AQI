const mongoose = require('mongoose');

const buildingSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  code: {
    type: String,
    unique: true,
    trim: true,
    uppercase: true
  },
  description: {
    type: String,
    trim: true
  },
  roomCount: {
    type: Number,
    default: 0
  },
  createdAt: {
    type: Date,
    default: Date.now,
    immutable: true
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

// KOMENTARI SEMUA HOOKS UNTUK SEKARANG
// buildingSchema.pre('save', function(next) {
//   this.updatedAt = Date.now();
//   next();
// });

// buildingSchema.pre('findOneAndUpdate', function(next) {
//   this.set({ updatedAt: Date.now() });
//   next();
// });

module.exports = mongoose.model('Building', buildingSchema);