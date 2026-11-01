const axios = require('axios');
const cron = require('node-cron');
const Room = require('../models/Room');
const IoTDevice = require('../models/IoTDevice');
const SensorData = require('../models/SensorData');
const { getAQICategory, calculateAQI } = require('../utils/aqiCalculator');

class IoTService {
  constructor() {
    this.isRunning = false;
    this.task = null;
    this.io = null;
    this.deviceLastData = new Map();
    this.pollingInterval = 10000;
  }

  start(io) {
    if (this.isRunning) {
      console.log('⚠️ IoT Service is already running');
      return;
    }

    this.io = io;
    console.log(`🚀 Starting IoT Service (polling every ${this.pollingInterval/1000}s)...`);

    this.task = cron.schedule('*/10 * * * * *', async () => {
      await this.pollAllIoTDevices();
    });

    this.isRunning = true;
    console.log('✅ IoT Service started');
    this.pollAllIoTDevices();
  }

  stop() {
    if (this.task) {
      this.task.stop();
      this.isRunning = false;
      console.log('⏹️ IoT Service stopped');
    }
  }

  async pollAllIoTDevices() {
    try {
      const devices = await IoTDevice.find({});

      if (devices.length === 0) {
        console.log('ℹ️ No IoT devices to poll');
        return;
      }

      console.log(`🔄 Polling ${devices.length} IoT devices...`);

      const pollPromises = devices.map(device =>
        this.pollDevice(device).catch(error => {
          console.error(`❌ Error polling device ${device.name}:`, error.message);
          return null;
        })
      );

      const results = await Promise.allSettled(pollPromises);

      const successfulPolls = results.filter(
        r => r.status === 'fulfilled' && r.value && r.value.success
      ).length;

      console.log(`✅ IoT polling completed: ${successfulPolls}/${devices.length} successful`);
      console.log(`✅ Updated at ${new Date().toLocaleTimeString()}`);
    } catch (error) {
      console.error('❌ Error in pollAllIoTDevices:', error.message);
    }
  }

  async pollDevice(device) {
    try {
      console.log(`📡 Polling device: ${device.name} (${device.apiEndpoint})`);
      const response = await axios.get(device.apiEndpoint, { timeout: 5000 });

      if (response.data?.success === true) {
        const iotData = response.data.data;

        if (!this.isValidIoTData(iotData)) {
          throw new Error('Invalid IoT data structure');
        }

        const lastData = this.deviceLastData.get(device._id.toString());
        const hasChanged = this._hasDataChanged(lastData, iotData);

        this.deviceLastData.set(device._id.toString(), iotData);

        device.status = 'online';
        device.lastUpdate = new Date();
        await device.save();

        if (hasChanged || !lastData) {
          console.log(`🔄 Data changed for device ${device.name}, broadcasting...`);

          const rooms = await Room.find({
            iotDeviceId: device._id.toString()
          });

          for (const room of rooms) {
            await this.updateRoomFromIoT(room, iotData, device.name);
          }
        } else {
          console.log(`ℹ️ No data change for device ${device.name}, skipping broadcast`);
        }

        return { success: true, changed: hasChanged };
      }

      return { success: false, error: 'Device did not return success' };
    } catch (error) {
      device.status = 'offline';
      await device.save();

      console.error(`❌ Error polling device ${device.name}:`, error.message);
      return { success: false, error: error.message };
    }
  }

  isValidIoTData(data) {
    return data &&
           typeof data.aqi === 'number' &&
           typeof data.pm25 === 'number' &&
           typeof data.pm10 === 'number' &&
           typeof data.co === 'number' &&
           typeof data.temperature === 'number' &&
           typeof data.humidity === 'number';
  }

  _hasDataChanged(oldData, newData) {
    if (!oldData || !newData) return true;

    const thresholds = {
      aqi: 0, pm25: 0, pm10: 0, co: 0, temperature: 0, humidity: 0
    };

    return (
      Math.abs(newData.aqi - (oldData.aqi || 0)) > thresholds.aqi ||
      Math.abs(newData.pm25 - (oldData.pm25 || 0)) > thresholds.pm25 ||
      Math.abs(newData.pm10 - (oldData.pm10 || 0)) > thresholds.pm10 ||
      Math.abs(newData.co - (oldData.co || 0)) > thresholds.co ||
      Math.abs(newData.temperature - (oldData.temperature || 0)) > thresholds.temperature ||
      Math.abs(newData.humidity - (oldData.humidity || 0)) > thresholds.humidity
    );
  }

  async updateRoomFromIoT(room, iotData, deviceName) {
    try {
      // FIXED: skip room demoMode — jangan timpa nilai demo
      if (room.demoMode) {
        console.log(`ℹ️ Skipping room ${room.name} (demoMode active)`);
        return;
      }

      // FIXED: deteksi device error (nilai negatif) SEBELUM kalkulasi AQI
      if (iotData.aqi < 0 || iotData.pm25 < 0 || iotData.pm10 < 0) {
        await this.handleDeviceError(room, deviceName);
        return;
      }

      const aqiResult = calculateAQI(iotData.pm25, iotData.pm10, iotData.co);

      const normalizedData = {
        pm25: iotData.pm25,
        pm10: iotData.pm10,
        co: iotData.co,
        temperature: iotData.temperature,
        humidity: iotData.humidity,
        aqi: aqiResult.aqi,
        category: aqiResult.category,
        dominant: aqiResult.dominant,
      };

      const currentData = room.currentData;
      const hasRoomDataChanged = this._hasDataChanged(
        {
          aqi: room.currentAQI,
          pm25: currentData.pm25,
          pm10: currentData.pm10,
          co: currentData.co,
          temperature: currentData.temperature,
          humidity: currentData.humidity,
        },
        normalizedData
      );

      if (!hasRoomDataChanged) {
        console.log(`ℹ️ Room ${room.name} data unchanged (exact match), skipping update`);
        return;
      }

      room.currentAQI = normalizedData.aqi;
      room.currentData = {
        pm25: normalizedData.pm25,
        pm10: normalizedData.pm10,
        co: normalizedData.co,
        temperature: normalizedData.temperature,
        humidity: normalizedData.humidity,
        updatedAt: new Date(),
      };
      room.updatedAt = new Date();
      await room.save();

      const historicalData = new SensorData({
        roomId: room._id,
        roomName: room.name,
        buildingName: room.buildingName,
        aqi: normalizedData.aqi,
        pm25: normalizedData.pm25,
        pm10: normalizedData.pm10,
        co: normalizedData.co,
        temperature: normalizedData.temperature,
        humidity: normalizedData.humidity,
        category: aqiResult.category,
        timestamp: new Date(),
      });
      await historicalData.save();

      this.broadcastRoomUpdate(room, normalizedData, 'iot', deviceName);

      // Log extra untuk kategori tinggi
      if (aqiResult.aqi > 100) {
        console.log(
          `🚨 HIGH AQI in ${room.name} (IoT ${deviceName}): ${aqiResult.aqi} (${aqiResult.category})`
        );
      } else {
        console.log(
          `✅ IoT room ${room.name}: AQI ${normalizedData.aqi} (${aqiResult.dominant.toUpperCase()}), PM2.5=${normalizedData.pm25}, PM10=${normalizedData.pm10}`
        );
      }
    } catch (error) {
      console.error(`❌ Error updating IoT room ${room.name}:`, error.message);
    }
  }

  async updateRoomFromIoTForce(room, iotData, deviceName) {
    try {
      if (room.demoMode) {
        console.log(`ℹ️ Skipping force update ${room.name} (demoMode active)`);
        return;
      }

      // FIXED: handle error juga di force path
      if (iotData.aqi < 0 || iotData.pm25 < 0 || iotData.pm10 < 0) {
        await this.handleDeviceError(room, deviceName);
        return;
      }

     const aqiResult = calculateAQI(iotData.pm25, iotData.pm10, iotData.co);

      room.currentAQI = aqiResult.aqi;
      room.currentData = {
        pm25: iotData.pm25,
        pm10: iotData.pm10,
        co: iotData.co,
        temperature: iotData.temperature,
        humidity: iotData.humidity,
        updatedAt: new Date(),
      };
      room.updatedAt = new Date();
      await room.save();

      const historicalData = new SensorData({
        roomId: room._id,
        roomName: room.name,
        buildingName: room.buildingName,
        aqi: aqiResult.aqi,
        pm25: iotData.pm25,
        pm10: iotData.pm10,
        co: iotData.co,
        temperature: iotData.temperature,
        humidity: iotData.humidity,
        category: aqiResult.category,
        timestamp: new Date(),
      });
      await historicalData.save();

      this.broadcastRoomUpdate(room, iotData, 'iot', deviceName);

      console.log(
        `✅ FORCE-updated IoT room ${room.name}: AQI ${aqiResult.aqi} (${aqiResult.dominant.toUpperCase()})`
      );
    } catch (error) {
      console.error(`❌ Error force-updating room ${room.name}:`, error.message);
    }
  }

  /**
   * FIXED: handle device error (aqi=-1, pm<0).
   * Strategi SAMA dengan simulationService:
   *  - Catat ke SensorData (untuk history)
   *  - JANGAN overwrite room.currentAQI/currentData
   *  - Broadcast notification ke dashboard
   */
  async handleDeviceError(room, deviceName) {
    try {
      await new SensorData({
        roomId: room._id,
        roomName: room.name,
        buildingName: room.buildingName,
        aqi: -1,
        pm25: -1,
        pm10: -1,
        co: -1,
        temperature: -1,
        humidity: -1,
        category: 'error',
        timestamp: new Date(),
      }).save();

      if (this.io) {
        this.io.to(room._id.toString()).emit('notification', {
          type: 'error',
          message: `Device "${deviceName}" pada ${room.name} melaporkan error. Room tetap menampilkan nilai valid terakhir.`,
          timestamp: new Date(),
        });
      }

      console.log(
        `⚠️ IoT SENSOR ERROR in ${room.name} (device: ${deviceName}) — room retained last good value`
      );
    } catch (err) {
      console.error(`❌ Error handling device error for ${room.name}:`, err.message);
    }
  }

  async forceUpdateRoom(roomId) {
    try {
      const room = await Room.findById(roomId);
      if (!room) return { success: false, message: 'Room not found' };

      if (room.dataSource !== 'iot' || !room.iotDeviceId) {
        return { success: false, message: 'Room is not configured for IoT' };
      }

      const device = await IoTDevice.findById(room.iotDeviceId);
      if (!device) return { success: false, message: 'IoT device not found' };

      const response = await axios.get(device.apiEndpoint, { timeout: 5000 });

      if (response.data?.success !== true) {
        return { success: false, message: 'Device did not return success' };
      }

      const iotData = response.data.data;
      if (!this.isValidIoTData(iotData)) {
        return { success: false, message: 'Invalid IoT data structure' };
      }

      device.status = 'online';
      device.lastUpdate = new Date();
      await device.save();

      this.deviceLastData.set(device._id.toString(), iotData);

      await this.updateRoomFromIoTForce(room, iotData, device.name);

      return { success: true, data: iotData, deviceName: device.name };
    } catch (error) {
      console.error(`❌ forceUpdateRoom(${roomId}) error:`, error.message);
      return { success: false, error: error.message };
    }
  }

  async pollDeviceForce(device) {
    try {
      const response = await axios.get(device.apiEndpoint, { timeout: 5000 });

      if (response.data?.success !== true) {
        return { success: false, message: 'Device did not return success' };
      }

      const iotData = response.data.data;
      if (!this.isValidIoTData(iotData)) {
        return { success: false, message: 'Invalid IoT data' };
      }

      this.deviceLastData.set(device._id.toString(), iotData);

      device.status = 'online';
      device.lastUpdate = new Date();
      await device.save();

      const rooms = await Room.find({ iotDeviceId: device._id.toString() });
      for (const room of rooms) {
        await this.updateRoomFromIoTForce(room, iotData, device.name);
      }

      return { success: true, changed: true };
    } catch (error) {
      device.status = 'offline';
      await device.save().catch(() => {});
      return { success: false, error: error.message };
    }
  }

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

      this.io.to(room._id.toString()).emit('room-update', updateData);

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

  async forcePollAll() {
    console.log('🔄 FORCE polling all IoT devices...');
    try {
      const devices = await IoTDevice.find({});
      if (devices.length === 0) {
        return { success: true, message: 'No IoT devices to poll', count: 0 };
      }

      const results = await Promise.allSettled(
        devices.map(d => this.pollDeviceForce(d).catch(e => null))
      );

      const successCount = results.filter(
        r => r.status === 'fulfilled' && r.value?.success
      ).length;

      console.log(`✅ FORCE poll completed: ${successCount}/${devices.length}`);
      return {
        success: true,
        message: 'Force poll completed',
        polled: devices.length,
        successful: successCount
      };
    } catch (error) {
      console.error('❌ forcePollAll error:', error.message);
      return { success: false, error: error.message };
    }
  }

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

const iotService = new IoTService();
module.exports = iotService;