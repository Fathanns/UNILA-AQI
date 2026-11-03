const mongoose = require('mongoose');

const sensorDataSchema = new mongoose.Schema({
  roomId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Room',
    required: true
  },
  roomName: {
    type: String,
    required: true
  },
  buildingName: {
    type: String,
    required: true
  },
  aqi: {
    type: Number,
    required: true
  },
  pm25: {
    type: Number,
    required: true
  },
  pm10: {
    type: Number,
    required: true
  },
  co: {
    type: Number,
    required: true
  },
  so2: {
    type: Number,
    default: null
  },
  o3: {
    type: Number,
    default: null
  },
  no2: {
    type: Number,
    default: null
  },
  temperature: {
    type: Number,
    required: true
  },
  humidity: {
    type: Number,
    required: true
  },
  category: {
    type: String,
    enum: ['baik', 'sedang', 'tidak_sehat', 'sangat_tidak_sehat', 'berbahaya', 'error'], // TAMBAH 'error'
    required: true
  },
  timestamp: {
    type: Date,
    default: Date.now,
    index: true
  }
});

// Create index untuk query yang cepat
sensorDataSchema.index({ roomId: 1, timestamp: -1 });
sensorDataSchema.index({ timestamp: -1 });

module.exports = mongoose.model('SensorData', sensorDataSchema);