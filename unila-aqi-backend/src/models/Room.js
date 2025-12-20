const mongoose = require('mongoose');

const roomSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  building: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Building',
    required: true
  },
  buildingName: {
    type: String,
    required: true
  },
  dataSource: {
    type: String,
    enum: ['simulation', 'iot'],
    default: 'simulation'
  },
  iotDeviceId: {
    type: String,
    default: null
  },
  isActive: {
    type: Boolean,
    default: true
  },
  currentAQI: {
    type: Number,
    default: 0
  },
  currentData: {
    pm25: { type: Number, default: 0 },
    pm10: { type: Number, default: 0 },
    co2: { type: Number, default: 0 },
    temperature: { type: Number, default: 0 },
    humidity: { type: Number, default: 0 },
    updatedAt: { type: Date }
  },
  createdAt: {
    type: Date,
    default: Date.now
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

module.exports = mongoose.model('Room', roomSchema);