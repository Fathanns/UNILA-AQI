const axios = require('axios');
const cron = require('node-cron');
const Room = require('../models/Room');
const IoTDevice = require('../models/IoTDevice');
const SensorData = require('../models/SensorData');
const { getAQICategory } = require('../utils/aqiCalculator');
const { generateSensorData, simulateAnomaly } = require('../utils/dataGenerator');

class IoTService {
  constructor() {
    this.isRunning = false;
    this.task = null;
    this.io = null;
  }

  /**
   * Start IoT polling service
   */
  start(io) {
    if (this.isRunning) {
      console.log('⚠️ IoT Service is already running');
      return;
    }

    this.io = io;
    console.log('🚀 Starting IoT Service with Socket.io...');

    // Schedule task to run every 30 seconds
    this.task = cron.schedule('*/30 * * * * *', async () => {
      await this.pollAllIoTDevices();
    });

    this.isRunning = true;
    console.log('✅ IoT Service started (polling every 30 seconds)');

    // Initial poll
    this.pollAllIoTDevices();
  }

  /**
   * Stop IoT service
   */
  stop() {
    if (this.task) {
      this.task.stop();
      this.isRunning = false;
      console.log('⏹️ IoT Service stopped');
    }
  }

  /**
   * Poll all IoT devices and update rooms
   */
  async pollAllIoTDevices() {
    try {
      // Get all active IoT devices
      const devices = await IoTDevice.find({ 
        isActive: true,
        status: { $ne: 'error' }
      });

      console.log(`🔄 Polling ${devices.length} IoT devices...`);

      for (const device of devices) {
        await this.pollDevice(device);
      }

      console.log(`✅ IoT polling completed at ${new Date().toLocaleTimeString()}`);
    } catch (error) {
      console.error('❌ Error polling IoT devices:', error.message);
    }
  }

  /**
   * Poll single IoT device
   */
  async pollDevice(device) {
    try {
      console.log(`📡 Polling device: ${device.name} (${device.apiEndpoint})`);

      // Fetch data from IoT endpoint
      const response = await axios.get(device.apiEndpoint, {
        timeout: 5000 // 5 seconds timeout
      });

      if (response.data && response.data.success === true) {
        const iotData = response.data.data;
        
        // Update device status
        device.status = 'online';
        device.lastUpdate = new Date();
        device.updatedAt = new Date();
        await device.save();

        console.log(`✅ Device ${device.name} response:`, {
          aqi: iotData.aqi,
          pm25: iotData.pm25,
          temperature: iotData.temperature
        });

        // Find rooms using this device
        const rooms = await Room.find({ 
          iotDeviceId: device._id.toString(),
          isActive: true 
        });

        // Update each room
        for (const room of rooms) {
          await this.updateRoomFromIoT(room, iotData, device.name);
        }

      } else {
        // Invalid response format - use simulation as fallback
        device.status = 'error';
        device.updatedAt = new Date();
        await device.save();
        console.warn(`⚠️ Invalid response from ${device.name}, using simulation data`);
        
        // Update rooms with simulation data as fallback
        const rooms = await Room.find({ 
          iotDeviceId: device._id.toString(),
          isActive: true 
        });
        
        for (const room of rooms) {
          await this.updateRoomWithFallbackData(room);
        }
      }

    } catch (error) {
      console.error(`❌ Error polling device ${device.name}:`, error.message);
      
      // Update device status
      device.status = 'offline';
      device.updatedAt = new Date();
      await device.save();
      
      // Use simulation data as fallback
      const rooms = await Room.find({ 
        iotDeviceId: device._id.toString(),
        isActive: true 
      });
      
      for (const room of rooms) {
        await this.updateRoomWithFallbackData(room);
      }
    }
  }

  /**
   * Update room with fallback simulation data
   */
  async updateRoomWithFallbackData(room) {
    try {
      const roomType = this.getRoomType(room.name);
      const sensorData = generateSensorData(roomType);
      const aqiInfo = getAQICategory(sensorData.aqi);

      // Update room's current data
      room.currentAQI = sensorData.aqi;
      room.currentData = {
        pm25: sensorData.pm25,
        pm10: sensorData.pm10,
        co2: sensorData.co2,
        temperature: sensorData.temperature,
        humidity: sensorData.humidity,
        updatedAt: new Date()
      };
      room.updatedAt = new Date();

      await room.save();

      // Save historical data
      const historicalData = new SensorData({
        roomId: room._id,
        roomName: room.name,
        buildingName: room.buildingName,
        aqi: sensorData.aqi,
        pm25: sensorData.pm25,
        pm10: sensorData.pm10,
        co2: sensorData.co2,
        temperature: sensorData.temperature,
        humidity: sensorData.humidity,
        category: sensorData.category,
        timestamp: new Date()
      });

      await historicalData.save();

      // Broadcast update via Socket.io
      if (this.io) {
        this.io.to(room._id.toString()).emit('room-update', {
          roomId: room._id,
          data: {
            currentAQI: room.currentAQI,
            currentData: room.currentData,
            updatedAt: room.updatedAt
          },
          timestamp: new Date(),
          source: 'fallback'
        });
        
        console.log(`📢 Broadcast fallback update for room ${room.name}: AQI ${sensorData.aqi}`);
      }

      console.log(`✅ Updated room ${room.name} with fallback data: AQI ${sensorData.aqi}`);

    } catch (error) {
      console.error(`❌ Error updating room ${room.name} with fallback:`, error.message);
    }
  }

  /**
   * Update room data from IoT response
   */
  async updateRoomFromIoT(room, iotData, deviceName) {
    try {
      // Validate required fields
      if (!iotData.aqi || !iotData.pm25 || !iotData.pm10 || !iotData.co2 || 
          !iotData.temperature || !iotData.humidity) {
        console.warn(`⚠️ Incomplete data from ${deviceName} for room ${room.name}`);
        await this.updateRoomWithFallbackData(room);
        return;
      }

      // Get AQI category
      const aqiInfo = getAQICategory(iotData.aqi);

      // Update room's current data
      room.currentAQI = iotData.aqi;
      room.currentData = {
        pm25: iotData.pm25,
        pm10: iotData.pm10,
        co2: iotData.co2,
        temperature: iotData.temperature,
        humidity: iotData.humidity,
        updatedAt: new Date()
      };
      room.updatedAt = new Date();

      await room.save();

      // Save historical data
      const historicalData = new SensorData({
        roomId: room._id,
        roomName: room.name,
        buildingName: room.buildingName,
        aqi: iotData.aqi,
        pm25: iotData.pm25,
        pm10: iotData.pm10,
        co2: iotData.co2,
        temperature: iotData.temperature,
        humidity: iotData.humidity,
        category: aqiInfo.category,
        timestamp: new Date()
      });

      await historicalData.save();

      // Broadcast update via Socket.io
      if (this.io) {
        this.io.to(room._id.toString()).emit('room-update', {
          roomId: room._id,
          data: {
            currentAQI: room.currentAQI,
            currentData: room.currentData,
            updatedAt: room.updatedAt
          },
          timestamp: new Date(),
          source: 'iot',
          deviceName: deviceName
        });
        
        console.log(`📢 Broadcast IoT update for room ${room.name}: AQI ${iotData.aqi}`);
      }

      console.log(`✅ Updated room ${room.name} from IoT: AQI ${iotData.aqi}`);

    } catch (error) {
      console.error(`❌ Error updating room ${room.name}:`, error.message);
      await this.updateRoomWithFallbackData(room);
    }
  }

  /**
   * Determine room type based on name
   */
  getRoomType(roomName) {
    const name = roomName.toLowerCase();
    
    if (name.includes('lab') || name.includes('praktikum')) {
      return 'laboratory';
    } else if (name.includes('kelas') || name.includes('ruang') || name.includes('r.') || name.includes('gd.')) {
      return 'classroom';
    } else if (name.includes('perpustakaan') || name.includes('library')) {
      return 'library';
    } else if (name.includes('aula') || name.includes('auditorium') || name.includes('hall')) {
      return 'crowded';
    }
    
    return 'normal';
  }

  /**
   * Manually trigger polling for a specific device
   */
  async pollDeviceById(deviceId) {
    try {
      const device = await IoTDevice.findById(deviceId);
      if (device) {
        await this.pollDevice(device);
        return { 
          success: true, 
          message: 'Device polled successfully',
          device: {
            id: device._id,
            name: device.name,
            status: device.status,
            lastUpdate: device.lastUpdate
          }
        };
      }
      return { success: false, message: 'Device not found' };
    } catch (error) {
      throw new Error(`Error polling device: ${error.message}`);
    }
  }

  /**
   * Get IoT service status
   */
  getStatus() {
    return {
      isRunning: this.isRunning,
      lastUpdate: new Date(),
      nextUpdate: new Date(Date.now() + 30000), // 30 seconds from now
      socketConnected: this.io !== null
    };
  }
}

// Create singleton instance
const iotService = new IoTService();

module.exports = iotService;