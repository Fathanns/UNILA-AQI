const cron = require('node-cron');
const Room = require('../models/Room');
const SensorData = require('../models/SensorData');
const { getAQICategory, calculateAQI } = require('../utils/aqiCalculator');
const {
  generateSensorData,
  simulateAnomaly,
} = require('../utils/dataGenerator');

class SimulationService {
  constructor() {
    this.isRunning = false;
    this.task = null;
    this.io = null;
    this.updateInterval = 30000;
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
    const { runExclusive } = require('../utils/serviceLock');

    return runExclusive(async () => {
      try {
        const rooms = await Room.find({
          dataSource: 'simulation',
          demoMode: { $ne: true }
        });

        if (rooms.length === 0) {
          console.log('ℹ️ No active simulation rooms to update');
          return;
        }

        console.log(`\n🔄 Updating ${rooms.length} simulation rooms...`);

        for (const room of rooms) {
          await this.updateRoom(room);
        }

        console.log(`\n🕒 Updated ${rooms.length} rooms at ${new Date().toLocaleTimeString()} \n`);
      } catch (error) {
        console.error('❌ Error in updateAllRooms:', error.message);
      }
    });
  }

  async updateRoom(room) {
    try {
      const roomType = this.getRoomType(room.name);

      const normalData = generateSensorData(roomType);
      const sensorData = simulateAnomaly(normalData);

      if (sensorData.isAnomaly && sensorData.anomalyType === 'error') {
        await this.handleSensorError(room, sensorData);
        return;
      }

      const aqiResult = calculateAQI(
        sensorData.pm25,
        sensorData.pm10,
        sensorData.co,
        sensorData.so2,
        sensorData.o3,
        sensorData.no2
      );

      sensorData.aqi = aqiResult.aqi;
      sensorData.category = aqiResult.category;
      sensorData.dominant = aqiResult.dominant;
      sensorData.ispuPM25 = aqiResult.ispuPM25;
      sensorData.ispuPM10 = aqiResult.ispuPM10;
      sensorData.ispuCO = aqiResult.ispuCO;
      sensorData.ispuSO2 = aqiResult.ispuSO2;
      sensorData.ispuO3 = aqiResult.ispuO3;
      sensorData.ispuNO2 = aqiResult.ispuNO2;

      const hasChanged = this._hasDataChanged(room, sensorData);

      if (!hasChanged) {
        console.log(`ℹ️ Room ${room.name} data unchanged (exact match), skipping update`);
        return;
      }

      room.currentAQI = sensorData.aqi;
      room.currentData = {
        pm25: sensorData.pm25,
        pm10: sensorData.pm10,
        co: sensorData.co,
        so2: sensorData.so2,
        o3: sensorData.o3,
        no2: sensorData.no2,
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
        co: sensorData.co,
        so2: sensorData.so2,
        o3: sensorData.o3,
        no2: sensorData.no2,
        temperature: sensorData.temperature,
        humidity: sensorData.humidity,
        category: sensorData.category,
        timestamp: new Date(),
        isAnomaly: sensorData.isAnomaly === true,
        anomalyType: sensorData.anomalyType || null,
      });

      await historicalData.save();

      console.log('┌────────────────────────────────────────────────────────────────────────────────────');

      this.broadcastRoomUpdate(room, sensorData);

      if (sensorData.isAnomaly) {
        console.log(
          `🚨 ANOMALY in ${room.name}: AQI ${sensorData.aqi} (${sensorData.category}) — type: ${sensorData.anomalyType}`
        );
      } else {
        console.log(
          `✅ Simulation room ${room.name}: AQI ${sensorData.aqi}, ` +
          `PM2.5=${sensorData.pm25}, PM10=${sensorData.pm10}, ` +
          `CO=${sensorData.co}, Suhu=${sensorData.temperature}, RH=${sensorData.humidity}`
        );
      }

      const dominantLabel = {
        pm25: `PM2.5 (ISPU=${sensorData.ispuPM25})`,
        pm10: `PM10 (ISPU=${sensorData.ispuPM10})`,
        co:   `CO (ISPU=${sensorData.ispuCO})`,
      }[sensorData.dominant] || sensorData.dominant;

      console.log(
        `⚠️  DOMINAN ${sensorData.dominant.toUpperCase()} in ${room.name}: AQI ${sensorData.aqi} (${dominantLabel})`
      );
      console.log('└────────────────────────────────────────────────────────────────────────────────────');
    } catch (error) {
      console.log('┌────────────────────────────────────────────────────────────────────────────────────');
      console.error(`❌ Error updating room ${room.name}:`, error.message);
      console.log('└────────────────────────────────────────────────────────────────────────────────────');
    }
  }

  async handleSensorError(room, sensorData) {
    try {
      await new SensorData({
        roomId: room._id,
        roomName: room.name,
        buildingName: room.buildingName,
        aqi: -1,
        pm25: -1, pm10: -1, co: -1, so2: -1, o3: -1, no2: -1,
        temperature: -1, humidity: -1,
        category: 'error',
        timestamp: new Date(),
        isAnomaly: true,
        anomalyType: 'error',
      }).save();

      // ✅ NOTIFIKASI SOCKET.IO DIHAPUS
      // (Tidak ada emit 'notification' agar Flutter tidak menampilkan Snackbar)

      console.log('┌────────────────────────────────────────────────────────────────────────────────────');
      console.log(
        `⚠️ SENSOR ERROR in ${room.name} (data invalid, room retained last good value)`
      );
      console.log('└────────────────────────────────────────────────────────────────────────────────────');
    } catch (err) {
      console.log('┌────────────────────────────────────────────────────────────────────────────────────');
      console.error(`❌ Error handling sensor error for ${room.name}:`, err.message);
      console.log('└────────────────────────────────────────────────────────────────────────────────────');
    }
  }

  _hasDataChanged(room, newData) {
    const currentData = room.currentData;

    const changed = (oldV, newV) => {
      if (oldV == null && newV == null) return false;
      if (oldV == null || newV == null) return true;
      return Math.abs(Number(newV) - Number(oldV)) > 0;
    };

    return (
      changed(room.currentAQI, newData.aqi) ||
      changed(currentData.pm25, newData.pm25) ||
      changed(currentData.pm10, newData.pm10) ||
      changed(currentData.co, newData.co) ||
      changed(currentData.so2, newData.so2) ||
      changed(currentData.o3, newData.o3) ||
      changed(currentData.no2, newData.no2) ||
      changed(currentData.temperature, newData.temperature) ||
      changed(currentData.humidity, newData.humidity)
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