const cron = require('node-cron');
const Room = require('../models/Room');
const SensorData = require('../models/SensorData');
const { generateSensorData, simulateAnomaly } = require('../utils/dataGenerator');
const { getAQICategory } = require('../utils/aqiCalculator');

class SimulationService {
  constructor() {
    this.isRunning = false;
    this.task = null;
  }

  /**
   * Start simulation for all active rooms
   */
  start() {
    if (this.isRunning) {
      console.log('⚠️ Simulation is already running');
      return;
    }

    console.log('🚀 Starting simulation service...');

    // Schedule task to run every minute
    this.task = cron.schedule('* * * * *', async () => {
      await this.updateAllRooms();
    });

    this.isRunning = true;
    console.log('✅ Simulation service started (updates every minute)');

    // Initial update
    this.updateAllRooms();
  }

  /**
   * Stop simulation
   */
  stop() {
    if (this.task) {
      this.task.stop();
      this.isRunning = false;
      console.log('⏹️ Simulation service stopped');
    }
  }

  /**
   * Update data for all rooms with simulation data source
   */
  async updateAllRooms() {
    try {
      // Get all active rooms with simulation data source
      const rooms = await Room.find({ 
        isActive: true, 
        dataSource: 'simulation' 
      }).populate('building', 'name');

      console.log(`🔄 Updating ${rooms.length} rooms...`);

      for (const room of rooms) {
        await this.updateRoomData(room);
      }

      console.log(`✅ Updated ${rooms.length} rooms at ${new Date().toLocaleTimeString()}`);
    } catch (error) {
      console.error('❌ Error updating rooms:', error.message);
    }
  }

  /**
   * Update data for a single room
   */
  async updateRoomData(room) {
    try {
      // Generate new sensor data
      let sensorData = generateSensorData(this.getRoomType(room.name));
      
      // Simulate anomalies occasionally
      sensorData = simulateAnomaly(sensorData);

      // Get AQI category info
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

      // Save historical data (keep last 7 days)
      const historicalData = new SensorData({
        roomId: room._id,
        roomName: room.name,
        buildingName: room.building?.name || room.buildingName,
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

      // Clean old data (older than 7 days)
      const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
      await SensorData.deleteMany({ 
        roomId: room._id, 
        timestamp: { $lt: sevenDaysAgo } 
      });

    } catch (error) {
      console.error(`❌ Error updating room ${room.name}:`, error.message);
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
   * Manually trigger update for a specific room
   */
  async updateRoomById(roomId) {
    try {
      const room = await Room.findById(roomId).populate('building', 'name');
      if (room && room.dataSource === 'simulation') {
        await this.updateRoomData(room);
        return { success: true, message: 'Room updated' };
      }
      return { success: false, message: 'Room not found or not simulation' };
    } catch (error) {
      throw new Error(`Error updating room: ${error.message}`);
    }
  }

  /**
   * Get simulation status
   */
  getStatus() {
    return {
      isRunning: this.isRunning,
      lastUpdate: new Date(),
      nextUpdate: new Date(Date.now() + 60000) // 1 minute from now
    };
  }
}

// Create singleton instance
const simulationService = new SimulationService();

module.exports = simulationService;