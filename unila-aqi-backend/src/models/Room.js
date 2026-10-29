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
  // FIXED: flag untuk demo mode — kalau true, simulationService & iotService
  // TIDAK akan menimpa nilai currentAQI. Dipakai untuk sidang/demo
  // agar dosen bisa melihat kategori AQI ekstrem secara deterministik.
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