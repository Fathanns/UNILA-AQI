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
  // FIXED: currentAQI nullable — null berarti "belum ada data valid".
  //   - null  → UI tampilkan card abu-abu "Tidak Ada Data"
  //   - 0..500 → nilai AQI normal
  currentAQI: {
    type: Number,
    default: null
  },
  // FIXED: semua field nullable. null berarti "tidak dikirim device".
  currentData: {
    pm25: { type: Number, default: null },
    pm10: { type: Number, default: null },
    co: { type: Number, default: null },
    so2: { type: Number, default: null },
    o3: { type: Number, default: null },
    no2: { type: Number, default: null },
    temperature: { type: Number, default: null },
    humidity: { type: Number, default: null },
    updatedAt: { type: Date }
  },
  demoMode: {
    type: Boolean,
    default: false
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

module.exports = mongoose.model('Room', roomSchema);