const axios = require('axios');
const cron = require('node-cron');
const Room = require('../models/Room');
const IoTDevice = require('../models/IoTDevice');
const SensorData = require('../models/SensorData');
const { getAQICategory } = require('../utils/aqiCalculator');

class IoTService {
  constructor() {
    this.isRunning = false;
    this.task = null;
    this.io = null;
    this.deviceLastData = new Map();
    this.pollingInterval = 10000; // 60 detik untuk IoT
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
    console.log(`🚀 Starting IoT Service (polling every ${this.pollingInterval/1000}s)...`);

    // Schedule task to run every 10 seconds
    this.task = cron.schedule('*/10 * * * * *', async () => {
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
  }

  /**
   * Poll all IoT devices
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

      // Poll devices in parallel
      const pollPromises = devices.map(device => 
        this.pollDevice(device).catch(error => {
          console.error(`❌ Error polling device ${device.name}:`, error.message);
          return null;
        })
      );

      const results = await Promise.allSettled(pollPromises);
      
      const successfulPolls = results.filter(r => r.status === 'fulfilled' && r.value).length;
      console.log(`✅ IoT polling completed: ${successfulPolls}/${devices.length} successful`);
      console.log(`✅ Updated at ${new Date().toLocaleTimeString()}`);
      
    } catch (error) {
      console.error('❌ Error in pollAllIoTDevices:', error.message);
    }
  }

  /**
   * Poll single IoT device
   */
  async pollDevice(device) {
    try {
      console.log(`📡 Polling device: ${device.name} (${device.apiEndpoint})`);
      const response = await axios.get(device.apiEndpoint, { timeout: 5000 });
      
      if (response.data?.success === true) {
        const iotData = response.data.data;
        
        // Validate IoT data structure
        if (!this.isValidIoTData(iotData)) {
          throw new Error('Invalid IoT data structure');
        }
        
        // Check if data has changed
        const lastData = this.deviceLastData.get(device._id.toString());
        const hasChanged = this._hasDataChanged(lastData, iotData);
        
        // Save last data
        this.deviceLastData.set(device._id.toString(), iotData);
        
        // Update device status
        device.status = 'online';
        device.lastUpdate = new Date();
        await device.save();
        
        // Broadcast if data changed
        if (hasChanged || !lastData) {
          console.log(`🔄 Data changed for device ${device.name}, broadcasting...`);
          
          // Find rooms using this device
          const rooms = await Room.find({ 
            iotDeviceId: device._id.toString(),
            isActive: true 
          });
          
          // Update and broadcast each room
          for (const room of rooms) {
            await this.updateRoomFromIoT(room, iotData, device.name);
          }
        } else {
          console.log(`ℹ️ No data change for device ${device.name}, skipping broadcast`);
        }
        
        return { success: true, changed: hasChanged };
      }
    } catch (error) {
      // Handle error
      device.status = error.code === 'ECONNABORTED' ? 'offline' : 'error';
      await device.save();
      
      console.error(`❌ Error polling device ${device.name}:`, error.message);
      return { success: false, error: error.message };
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
   * Check if data has changed significantly
   */
  _hasDataChanged(oldData, newData) {
    if (!oldData || !newData) return true;
    
    const thresholds = {
      aqi: 1,
      pm25: 1.0,
      pm10: 1.0,
      co2: 1,
      temperature: 0.5,
      humidity: 1.0
    };
    
    return (
      Math.abs(newData.aqi - (oldData.aqi || 0)) > thresholds.aqi ||
      Math.abs(newData.pm25 - (oldData.pm25 || 0)) > thresholds.pm25 ||
      Math.abs(newData.pm10 - (oldData.pm10 || 0)) > thresholds.pm10 ||
      Math.abs(newData.co2 - (oldData.co2 || 0)) > thresholds.co2 ||
      Math.abs(newData.temperature - (oldData.temperature || 0)) > thresholds.temperature ||
      Math.abs(newData.humidity - (oldData.humidity || 0)) > thresholds.humidity
    );
  }

  /**
   * Update room from IoT data
   */
  async updateRoomFromIoT(room, iotData, deviceName) {
    try {
      // Check if room data has changed
      const currentData = room.currentData;
      const hasRoomDataChanged = this._hasDataChanged(
        {
          aqi: room.currentAQI,
          pm25: currentData.pm25,
          pm10: currentData.pm10,
          co2: currentData.co2,
          temperature: currentData.temperature,
          humidity: currentData.humidity
        },
        iotData
      );
      
      if (!hasRoomDataChanged) {
        console.log(`ℹ️ Room ${room.name} data unchanged, skipping update`);
        return;
      }
      
      // Update room data
      const aqiInfo = getAQICategory(iotData.aqi);
      
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
        ...iotData,
        category: aqiInfo.category,
        timestamp: new Date()
      });
      
      await historicalData.save();
      
      // Broadcast via WebSocket
      this.broadcastRoomUpdate(room, iotData, 'iot', deviceName);
      
      console.log(`✅ Updated & broadcasted IoT room ${room.name}: AQI ${iotData.aqi}`);
      
    } catch (error) {
      console.error(`❌ Error updating IoT room ${room.name}:`, error.message);
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

      console.log(`📢 Broadcast IoT update for room ${room.name}: AQI ${room.currentAQI}`);
    }
  }

  /**
   * Manually trigger polling
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
      pollingInterval: this.pollingInterval
    };
  }
}

// Create singleton instance
const iotService = new IoTService();

module.exports = iotService;