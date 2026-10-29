const cron = require('node-cron');
const Room = require('../models/Room');
const SensorData = require('../models/SensorData');
const { getAQICategory } = require('../utils/aqiCalculator');
const {
  generateSensorData,
  simulateAnomaly,
} = require('../utils/dataGenerator');

class SimulationService {
  constructor() {
    this.isRunning = false;
    this.task = null;
    this.io = null;
    this.updateInterval = 10000;
  }

  start(io) {
    if (this.isRunning) {
      console.log('⚠️ Simulation Service is already running');
      return;
    }

    this.io = io;
    console.log(`🚀 Starting Simulation Service (update every ${this.updateInterval/1000}s)...`);

    this.task = cron.schedule(`*/${this.updateInterval/1000} * * * * *`, async () => {
      await this.updateAllRooms();
    });

    this.isRunning = true;
    console.log('✅ Simulation Service started');
    this.updateAllRooms();
  }

  stop() {
    if (this.task) {
      this.task.stop();
      this.isRunning = false;
      console.log('⏹️ Simulation Service stopped');
    }
  }

  async updateAllRooms() {
    try {
      // FIXED: skip room yang sedang dalam demoMode
      const rooms = await Room.find({
        dataSource: 'simulation',
        demoMode: { $ne: true }
      });

      if (rooms.length === 0) {
        console.log('ℹ️ No active simulation rooms to update');
        return;
      }

      console.log(`🔄 Updating ${rooms.length} simulation rooms...`);

      for (const room of rooms) {
        await this.updateRoom(room);
      }

      console.log(`✅ Updated ${rooms.length} rooms at ${new Date().toLocaleTimeString()}`);
    } catch (error) {
      console.error('❌ Error in updateAllRooms:', error.message);
    }
  }

  async updateRoom(room) {
    try {
      const roomType = this.getRoomType(room.name);

      // FIXED: 1) generate normal, 2) post-process dengan anomaly
      const normalData = generateSensorData(roomType);
      const sensorData = simulateAnomaly(normalData);

      // FIXED: error sensor ditangani terpisah — TIDAK overwrite room
      if (sensorData.isAnomaly && sensorData.anomalyType === 'error') {
        await this.handleSensorError(room, sensorData);
        return;
      }

      const hasChanged = this._hasDataChanged(room, sensorData);

      if (!hasChanged) {
        console.log(`ℹ️ Room ${room.name} data unchanged (exact match), skipping update`);
        return;
      }

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

      this.broadcastRoomUpdate(room, sensorData);

      if (sensorData.isAnomaly) {
        console.log(
          `🚨 ANOMALY in ${room.name}: AQI ${sensorData.aqi} (${sensorData.category}) — type: ${sensorData.anomalyType}`
        );
      }
    } catch (error) {
      console.error(`❌ Error updating room ${room.name}:`, error.message);
    }
  }

  /**
   * FIXED: saat sensor error (aqi=-1):
   *  - Catat ke SensorData (untuk grafik history)
   *  - JANGAN overwrite room.currentAQI agar dashboard tetap menampilkan
   *    nilai valid terakhir (tidak menipu pengguna dengan -1)
   *  - Broadcast notification
   */
  async handleSensorError(room, sensorData) {
    try {
      await new SensorData({
        roomId: room._id,
        roomName: room.name,
        buildingName: room.buildingName,
        aqi: -1,
        pm25: -1,
        pm10: -1,
        co2: -1,
        temperature: -1,
        humidity: -1,
        category: 'error',
        timestamp: new Date()
      }).save();

      if (this.io) {
        this.io.to(room._id.toString()).emit('notification', {
          type: 'error',
          message: `Sensor pada ${room.name} melaporkan error (data tidak valid).`,
          timestamp: new Date(),
        });
      }

      console.log(`⚠️ SENSOR ERROR in ${room.name} (data invalid, room retained last good value)`);
    } catch (err) {
      console.error(`❌ Error handling sensor error for ${room.name}:`, err.message);
    }
  }

  _hasDataChanged(room, newData) {
    const currentData = room.currentData;

    const thresholds = {
      aqi: 0,
      pm25: 0,
      pm10: 0,
      co2: 0,
      temperature: 0,
      humidity: 0
    };

    return (
      Math.abs(newData.aqi - room.currentAQI) > thresholds.aqi ||
      Math.abs(newData.pm25 - (currentData.pm25 || 0)) > thresholds.pm25 ||
      Math.abs(newData.pm10 - (currentData.pm10 || 0)) > thresholds.pm10 ||
      Math.abs(newData.co2 - (currentData.co2 || 0)) > thresholds.co2 ||
      Math.abs(newData.temperature - (currentData.temperature || 0)) > thresholds.temperature ||
      Math.abs(newData.humidity - (currentData.humidity || 0)) > thresholds.humidity
    );
  }

  broadcastRoomUpdate(room, data) {
    if (this.io) {
      const updateData = {
        roomId: room._id,
        data: {
          currentAQI: room.currentAQI,
          currentData: room.currentData,
          updatedAt: room.updatedAt
        },
        timestamp: new Date(),
        source: 'simulation'
      };

      this.io.to(room._id.toString()).emit('room-update', updateData);

      this.io.emit('dashboard-update', {
        type: 'room-data-updated',
        roomId: room._id,
        aqi: room.currentAQI,
        building: room.buildingName,
        timestamp: new Date()
      });

      console.log(`📢 Broadcast simulation update for room ${room.name}: AQI ${room.currentAQI}`);
    }
  }

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

  async forceUpdate() {
    console.log('🔄 Force updating all simulation rooms...');
    await this.updateAllRooms();
    return { success: true, message: 'Force simulation update completed' };
  }

  getStatus() {
    return {
      isRunning: this.isRunning,
      lastUpdate: new Date(),
      nextUpdate: new Date(Date.now() + this.updateInterval),
      socketConnected: this.io !== null,
      updateInterval: this.updateInterval
    };
  }
}

const simulationService = new SimulationService();
module.exports = simulationService;