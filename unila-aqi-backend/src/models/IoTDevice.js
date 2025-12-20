const mongoose = require('mongoose');

const iotDeviceSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  description: {
    type: String,
    trim: true
  },
  building: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Building'
  },
  buildingName: {
    type: String
  },
  apiEndpoint: {
    type: String,
    required: true,
    trim: true
  },
  isActive: {
    type: Boolean,
    default: true
  },
  lastUpdate: {
    type: Date
  },
  status: {
    type: String,
    enum: ['online', 'offline', 'error'],
    default: 'offline'
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

module.exports = mongoose.model('IoTDevice', iotDeviceSchema);