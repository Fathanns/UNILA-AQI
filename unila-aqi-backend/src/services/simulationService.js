const cron = require('node-cron');
const Room = require('../models/Room');
const SensorData = require('../models/SensorData');
const { getAQICategory } = require('../utils/aqiCalculator');
const { generateSensorData } = require('../utils/dataGenerator');

class SimulationService {
  constructor() {
    this.isRunning = false;
    this.task = null;
    this.io = null;
    this.updateInterval = 60000; // 1 menit
  }

  /**
   * Start simulation service
   */
  start(io) {
    if (this.isRunning) {
      console.log('⚠️ Simulation Service is already running');
      return;
    }

    this.io = io;
    console.log(`🚀 Starting Simulation Service (update every ${this.updateInterval/1000}s)...`);

    // Schedule task to run every 1 minute
    this.task = cron.schedule(`*/${this.updateInterval/1000} * * * * *`, async () => {
      await this.updateAllRooms();
    });

    this.isRunning = true;
    console.log('✅ Simulation Service started');

    // Initial update immediately
    this.updateAllRooms();
  }

  /**
   * Stop simulation service
   */
  stop() {
    if (this.task) {
      this.task.stop();
      this.isRunning = false;
      console.log('⏹️ Simulation Service stopped');
    }
  }

  /**
   * Update all rooms with simulation data
   */
  async updateAllRooms() {
    try {
      // Get all active rooms with simulation data source
      const rooms = await Room.find({ 
        isActive: true,
        dataSource: 'simulation'
      });

      if (rooms.length === 0) {
        console.log('ℹ️ No active simulation rooms to update');
        return;
      }

      console.log(`🔄 Updating ${rooms.length} simulation rooms...`);

      // Update each room with simulation data
      for (const room of rooms) {
        await this.updateRoom(room);
      }

      console.log(`✅ Updated ${rooms.length} rooms at ${new Date().toLocaleTimeString()}`);

    } catch (error) {
      console.error('❌ Error in updateAllRooms:', error.message);
    }
  }

  /**
   * Update single room with simulation data
   */
  async updateRoom(room) {
    try {
      const roomType = this.getRoomType(room.name);
      const sensorData = generateSensorData(roomType);

      // Check if data has changed significantly
      const hasChanged = this._hasDataChanged(room, sensorData);
      
      if (!hasChanged) {
        console.log(`ℹ️ Room ${room.name} data unchanged, skipping update`);
        return;
      }

      // Update room data
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
      this.broadcastRoomUpdate(room, sensorData);

    } catch (error) {
      console.error(`❌ Error updating room ${room.name}:`, error.message);
    }
  }

  /**
   * Check if data has changed significantly
   */
  _hasDataChanged(room, newData) {
    const currentData = room.currentData;
    
    // Define thresholds for significant change
    const thresholds = {
      aqi: 5,
      pm25: 2.0,
      pm10: 5.0,
      co2: 50,
      temperature: 0.5,
      humidity: 3.0
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

  /**
   * Broadcast room update via Socket.io
   */
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

      console.log(`📢 Broadcast simulation update for room ${room.name}: AQI ${room.currentAQI}`);
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
   * Manually trigger simulation update
   */
  async forceUpdate() {
    console.log('🔄 Force updating all simulation rooms...');
    await this.updateAllRooms();
    return { success: true, message: 'Force simulation update completed' };
  }

  /**
   * Get service status
   */
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

// Create singleton instance
const simulationService = new SimulationService();

module.exports = simulationService;