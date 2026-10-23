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
  apiEndpoint: {
    type: String,
    required: true,
    trim: true
  },
  lastUpdate: {
    type: Date
  },
  status: {
    type: String,
    enum: ['online', 'offline'],
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

module.exports = mongoose.model('IoTDevice', iotDeviceSchema);