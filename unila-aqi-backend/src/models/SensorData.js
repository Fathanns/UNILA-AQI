const mongoose = require('mongoose');

const sensorDataSchema = new mongoose.Schema({
  roomId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Room',
    required: true
  },
  roomName: { type: String, required: true },
  buildingName: { type: String, required: true },
  // FIXED: semua field nullable
  aqi: { type: Number, default: null },
  pm25: { type: Number, default: null },
  pm10: { type: Number, default: null },
  co: { type: Number, default: null },
  so2: { type: Number, default: null },
  o3: { type: Number, default: null },
  no2: { type: Number, default: null },
  temperature: { type: Number, default: null },
  humidity: { type: Number, default: null },
  category: {
    type: String,
    // FIXED: tambah 'no_data'
    enum: ['baik', 'sedang', 'tidak_sehat', 'sangat_tidak_sehat', 'berbahaya', 'error', 'no_data'],
    required: true
  },
  timestamp: {
    type: Date,
    default: Date.now,
    index: true
  }
});

sensorDataSchema.index({ roomId: 1, timestamp: -1 });
sensorDataSchema.index({ timestamp: -1 });

module.exports = mongoose.model('SensorData', sensorDataSchema);