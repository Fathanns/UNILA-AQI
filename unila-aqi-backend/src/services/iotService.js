const axios = require('axios');
const cron = require('node-cron');
const Room = require('../models/Room');
const IoTDevice = require('../models/IoTDevice');
const SensorData = require('../models/SensorData');
const { getAQICategory } = require('../utils/aqiCalculator');
const { generateSensorData } = require('../utils/dataGenerator');

class IoTService {
  constructor() {
    this.isRunning = false;
    this.task = null;
    this.io = null;
    this.activePolls = new Map(); // Store active polling for each device
    this.pollingInterval = 15000; // Reduce to 15 seconds for faster updates
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
    console.log(`🚀 Starting IoT Service with Socket.io (polling every ${this.pollingInterval/1000}s)...`);

    // Schedule task to run every 15 seconds instead of 30
    this.task = cron.schedule(`*/${this.pollingInterval/1000} * * * * *`, async () => {
      await this.pollAllIoTDevices();
    });

    this.isRunning = true;
    console.log('✅ IoT Service started');

    // Initial poll immediately
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
    
    // Clear all active polls
    this.activePolls.clear();
  }

  /**
   * Poll all IoT devices and update rooms - OPTIMIZED VERSION
   */
  async pollAllIoTDevices() {
    try {
      // Get all active IoT devices
      const devices = await IoTDevice.find({ 
        isActive: true
      });

      if (devices.length === 0) {
        console.log('ℹ️ No active IoT devices to poll');
        return;
      }

      console.log(`🔄 Polling ${devices.length} IoT devices...`);

      // Use Promise.all for parallel polling
      const pollPromises = devices.map(device => 
        this.pollDevice(device).catch(error => {
          console.error(`❌ Error polling device ${device.name}:`, error.message);
          return null;
        })
      );

      const results = await Promise.allSettled(pollPromises);
      
      const successfulPolls = results.filter(r => r.status === 'fulfilled' && r.value).length;
      console.log(`✅ IoT polling completed: ${successfulPolls}/${devices.length} successful`);
      
    } catch (error) {
      console.error('❌ Error in pollAllIoTDevices:', error.message);
    }
  }

  /**
   * Poll single IoT device - OPTIMIZED with faster response
   */
  async pollDevice(device) {
    // Check if already polling this device
    if (this.activePolls.has(device._id.toString())) {
      console.log(`⏳ Device ${device.name} is already being polled, skipping...`);
      return null;
    }

    // Mark as polling
    this.activePolls.set(device._id.toString(), true);

    try {
      console.log(`📡 Polling device: ${device.name} (${device.apiEndpoint})`);

      // Fetch data from IoT endpoint with shorter timeout
      const response = await axios.get(device.apiEndpoint, {
        timeout: 3000, // Reduced timeout to 3 seconds
        headers: {
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache'
        }
      });

      if (response.data && response.data.success === true) {
        const iotData = response.data.data;
        
        // Validate data structure
        if (!this.isValidIoTData(iotData)) {
          throw new Error('Invalid IoT data structure');
        }

        // Update device status
        device.status = 'online';
        device.lastUpdate = new Date();
        device.updatedAt = new Date();
        await device.save();

        console.log(`✅ Device ${device.name} response:`, {
          aqi: iotData.aqi,
          pm25: iotData.pm25,
          temperature: iotData.temperature,
          timestamp: new Date().toLocaleTimeString()
        });

        // Find rooms using this device
        const rooms = await Room.find({ 
          iotDeviceId: device._id.toString(),
          isActive: true 
        });

        if (rooms.length === 0) {
          console.log(`⚠️ No active rooms using device ${device.name}`);
        } else {
          // Update each room in parallel
          const updatePromises = rooms.map(room => 
            this.updateRoomFromIoT(room, iotData, device.name)
          );
          
          await Promise.all(updatePromises);
          console.log(`✅ Updated ${rooms.length} rooms from ${device.name}`);
        }

        return { success: true, device: device.name, data: iotData };

      } else {
        throw new Error('Invalid response format');
      }

    } catch (error) {
      console.error(`❌ Error polling device ${device.name}:`, error.message);
      
      // Update device status
      device.status = error.code === 'ECONNABORTED' || error.code === 'ETIMEDOUT' ? 'offline' : 'error';
      device.updatedAt = new Date();
      await device.save();
      
      // Use simulation data as fallback for rooms using this device
      const rooms = await Room.find({ 
        iotDeviceId: device._id.toString(),
        isActive: true 
      });
      
      if (rooms.length > 0) {
        const fallbackPromises = rooms.map(room => 
          this.updateRoomWithFallbackData(room)
        );
        
        await Promise.allSettled(fallbackPromises);
        console.log(`⚠️ Used fallback data for ${rooms.length} rooms from ${device.name}`);
      }
      
      return { success: false, device: device.name, error: error.message };
    } finally {
      // Remove from active polls
      this.activePolls.delete(device._id.toString());
    }
  }

  /**
   * Validate IoT data structure
   */
  isValidIoTData(data) {
    return data && 
           typeof data.aqi === 'number' &&
           typeof data.pm25 === 'number' &&
           typeof data.pm10 === 'number' &&
           typeof data.co2 === 'number' &&
           typeof data.temperature === 'number' &&
           typeof data.humidity === 'number';
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
      this.broadcastRoomUpdate(room, sensorData, 'fallback');

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
      if (!this.isValidIoTData(iotData)) {
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
      this.broadcastRoomUpdate(room, iotData, 'iot', deviceName);

      console.log(`✅ Updated room ${room.name} from IoT: AQI ${iotData.aqi}`);

    } catch (error) {
      console.error(`❌ Error updating room ${room.name}:`, error.message);
      await this.updateRoomWithFallbackData(room);
    }
  }

  /**
   * Broadcast room update via Socket.io
   */
  broadcastRoomUpdate(room, data, source, deviceName = null) {
    if (this.io) {
      const updateData = {
        roomId: room._id,
        data: {
          currentAQI: room.currentAQI,
          currentData: room.currentData,
          updatedAt: room.updatedAt
        },
        timestamp: new Date(),
        source: source,
        deviceName: deviceName
      };

      // Broadcast to room-specific channel
      this.io.to(room._id.toString()).emit('room-update', updateData);
      
      // Also broadcast to general updates channel for dashboard
      this.io.emit('dashboard-update', {
        type: 'room-data-updated',
        roomId: room._id,
        aqi: room.currentAQI,
        building: room.buildingName,
        timestamp: new Date()
      });

      console.log(`📢 Broadcast update for room ${room.name}: AQI ${room.currentAQI} (${source})`);
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
        const result = await this.pollDevice(device);
        return { 
          success: true, 
          message: 'Device polled successfully',
          result
        };
      }
      return { success: false, message: 'Device not found' };
    } catch (error) {
      throw new Error(`Error polling device: ${error.message}`);
    }
  }

  /**
   * Force immediate poll of all devices (for manual refresh)
   */
  async forcePollAll() {
    console.log('🔄 Force polling all IoT devices...');
    await this.pollAllIoTDevices();
    return { success: true, message: 'Force poll completed' };
  }

  /**
   * Get IoT service status
   */
  getStatus() {
    return {
      isRunning: this.isRunning,
      lastUpdate: new Date(),
      nextUpdate: new Date(Date.now() + this.pollingInterval),
      socketConnected: this.io !== null,
      activePolls: Array.from(this.activePolls.keys()),
      pollingInterval: this.pollingInterval
    };
  }
}

// Create singleton instance
const iotService = new IoTService();

module.exports = iotService;