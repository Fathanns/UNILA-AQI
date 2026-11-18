const axios = require('axios');
const cron = require('node-cron');
const Room = require('../models/Room');
const IoTDevice = require('../models/IoTDevice');
const SensorData = require('../models/SensorData');
const { getAQICategory, calculateAQI } = require('../utils/aqiCalculator');
const { runExclusive } = require('../utils/serviceLock');

// Helper border — dipakai konsisten di semua log blok
const BORDER_TOP = '┌────────────────────────────────────────────────────────────────────────────────────';
const BORDER_BOTTOM = '└────────────────────────────────────────────────────────────────────────────────────';

class IoTService {
  constructor() {
    this.isRunning = false;
    this.task = null;
    this.io = null;
    this.deviceLastData = new Map();
    this.pollingInterval = 30000;
    this._polling = false;        // ✅ guard anti-tumpang-tindih siklus cron
    this._maxRetries = 2;         // ✅ retry untuk device lambat / 503
    this._retryDelayMs = 3000;
  }

  start(io) {
    if (this.isRunning) {
      console.log('⚠️ IoT Service is already running');
      return;
    }

    this.io = io;
    console.log(`🚀 Starting IoT Service (polling every ${this.pollingInterval / 1000}s)...`);

    // IoT berjalan di detik ke-15 dan ke-45 setiap menit.
    this.task = cron.schedule('15,45 * * * * *', async () => {
      // ✅ Guard: jangan mulai siklus baru jika siklus sebelumnya belum selesai
      if (this._polling) {
        console.log('⏭️  Skipping poll — previous cycle still running');
        return;
      }

      this._polling = true;
      try {
        await this.pollAllIoTDevices();
      } finally {
        this._polling = false;
      }
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

  /**
   * Helper: GET dengan retry sederhana untuk device yang lambat / 503.
   */
  async _getWithRetry(url, timeoutMs = 15000) {
    let lastError;
    for (let attempt = 1; attempt <= this._maxRetries; attempt++) {
      try {
        return await axios.get(url, { timeout: timeoutMs });
      } catch (err) {
        lastError = err;
        if (attempt < this._maxRetries) {
          await new Promise((r) => setTimeout(r, this._retryDelayMs));
        }
      }
    }
    throw lastError;
  }

  async pollAllIoTDevices() {
    return runExclusive(async () => {
      try {
        const devices = await IoTDevice.find({});

        if (devices.length === 0) {
          console.log('ℹ️ No IoT devices to poll');
          return;
        }

        console.log(`🔄 Polling ${devices.length} IoT devices...`);

        // ✅ Cetak SERIAL di sini (bukan di dalam pollDevice yang paralel)
        devices.forEach((d) => {
          console.log(`📡 Polling device: ${d.name} (${d.apiEndpoint})`);
        });

        // Poll paralel, tapi TIDAK mencetak log di dalam pollDevice.
        const results = await Promise.allSettled(
          devices.map(async (device) => {
            try {
              const res = await this.pollDevice(device);
              return { ...res, deviceName: device.name };
            } catch (error) {
              return { success: false, deviceName: device.name, error: error.message };
            }
          })
        );

        // ✅ Log SERIAL — semua pakai console.log agar satu stream (stdout),
        // sehingga urutan border + isi dijamin konsisten.
        let successfulPolls = 0;
        for (const r of results) {
          const val =
            r.status === 'fulfilled'
              ? r.value
              : { success: false, deviceName: 'unknown', error: r.reason?.message };

          console.log(BORDER_TOP);
          if (val && val.success === true) {
            successfulPolls++;
            const lines = val.roomLogs || [];
            if (lines.length === 0) {
              console.log(
                `ℹ️  Device ${val.deviceName}: no rooms updated (no rooms mapped or all demoMode)`
              );
            } else {
              lines.forEach((line) => console.log(line));
            }
          } else {
            // ✅ console.log (bukan console.error) — hindari urutan acak stdout/stderr
            const name = val?.deviceName || 'unknown';
            const errMsg = val?.error || 'unknown error';
            console.log(`❌ Error polling device ${name}: ${errMsg}`);
          }
          console.log(BORDER_BOTTOM);
        }

        console.log(`\n✅ IoT polling completed: ${successfulPolls}/${devices.length} successful`);
        console.log(`🕒 Updated at ${new Date().toLocaleTimeString()}`);
        console.log('\n=====================================================================================\n');
      } catch (error) {
        console.error('❌ Error in pollAllIoTDevices:', error.message);
      }
    });
  }

  async pollDevice(device) {
    try {
      // ✅ TIDAK ada console.log di sini — dicetak serial oleh pollAllIoTDevices
      const response = await this._getWithRetry(device.apiEndpoint, 15000);

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

        const rooms = await Room.find({
          iotDeviceId: device._id.toString(),
        });

        const roomLogs = [];
        for (const room of rooms) {
          const { logs } = await this.updateRoomFromIoT(room, iotData, device.name);
          if (logs && logs.length) roomLogs.push(...logs);
        }

        return { success: true, changed: hasChanged, roomLogs };
      }

      return {
        success: false,
        deviceName: device.name,
        error: 'Device did not return success',
      };
    } catch (error) {
      device.status = 'offline';
      await device.save().catch(() => {});
      return {
        success: false,
        deviceName: device.name,
        error: error.message,
      };
    }
  }

  async checkDeviceStatus(devices) {
    if (!devices || devices.length === 0) return [];

    return runExclusive(async () => {
      const results = await Promise.allSettled(
        devices.map(async (device) => {
          try {
            await this._getWithRetry(device.apiEndpoint, 3000);
            return { id: device._id.toString(), status: 'online' };
          } catch (_) {
            return { id: device._id.toString(), status: 'offline' };
          }
        })
      );

      const updates = results
        .filter((r) => r.status === 'fulfilled' && r.value)
        .map((r) => r.value);

      if (updates.length > 0) {
        const bulkOps = updates.map((u) => ({
          updateOne: {
            filter: { _id: u.id },
            update: { $set: { status: u.status } },
          },
        }));

        try {
          await IoTDevice.bulkWrite(bulkOps);
        } catch (bulkErr) {
          console.error('❌ bulkWrite status check failed:', bulkErr.message);
        }
      }

      return updates;
    });
  }

  isValidIoTData(data) {
    if (!data || typeof data !== 'object') return false;

    const knownFields = [
      'aqi', 'pm25', 'pm10', 'co', 'so2', 'o3', 'no2',
      'temperature', 'humidity',
    ];
    return knownFields.some((k) => k in data);
  }

  _hasDataChanged(oldData, newData) {
    if (!oldData || !newData) return true;

    const changed = (oldV, newV) => {
      if (oldV == null && newV == null) return false;
      if (oldV == null || newV == null) return true;
      return Math.abs(Number(newV) - Number(oldV)) > 0;
    };

    return (
      changed(oldData.aqi, newData.aqi) ||
      changed(oldData.pm25, newData.pm25) ||
      changed(oldData.pm10, newData.pm10) ||
      changed(oldData.co, newData.co) ||
      changed(oldData.so2, newData.so2) ||
      changed(oldData.o3, newData.o3) ||
      changed(oldData.no2, newData.no2) ||
      changed(oldData.temperature, newData.temperature) ||
      changed(oldData.humidity, newData.humidity)
    );
  }

  _dominantLabel(aqiResult) {
    if (!aqiResult || !aqiResult.dominant) return null;
    return (
      {
        pm25: `PM2.5 (ISPU=${aqiResult.ispuPM25})`,
        pm10: `PM10 (ISPU=${aqiResult.ispuPM10})`,
        co:   `CO (ISPU=${aqiResult.ispuCO})`,
        so2:  `SO2 (ISPU=${aqiResult.ispuSO2})`,
        o3:   `O3 (ISPU=${aqiResult.ispuO3})`,
        no2:  `NO2 (ISPU=${aqiResult.ispuNO2})`,
      }[aqiResult.dominant] || aqiResult.dominant
    );
  }

  async updateRoomFromIoT(room, iotData, deviceName) {
    const logs = [];
    try {
      if (room.demoMode) {
        logs.push(`ℹ️  Skipping room ${room.name} (demoMode active)`);
        return { logs };
      }

      const optNum = (v) =>
        typeof v === 'number' && Number.isFinite(v) && !Number.isNaN(v) ? v : null;

      const pm25 = optNum(iotData.pm25);
      const pm10 = optNum(iotData.pm10);
      const co   = optNum(iotData.co);
      const so2  = optNum(iotData.so2);
      const o3   = optNum(iotData.o3);
      const no2  = optNum(iotData.no2);
      const temperature = optNum(iotData.temperature);
      const humidity    = optNum(iotData.humidity);

      const hasError = [pm25, pm10, co, so2, o3, no2, temperature, humidity]
        .some((v) => v !== null && v < 0);

      if (hasError) {
        await this.handleDeviceError(room, deviceName, logs);
        return { logs };
      }

      const aqiResult = calculateAQI(pm25, pm10, co, so2, o3, no2);

      const normalizedData = {
        aqi: aqiResult.aqi,
        pm25, pm10, co, so2, o3, no2,
        temperature, humidity,
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
          so2: currentData.so2,
          o3: currentData.o3,
          no2: currentData.no2,
          temperature: currentData.temperature,
          humidity: currentData.humidity,
        },
        normalizedData
      );

      if (!hasRoomDataChanged) {
        logs.push(`ℹ️  Room ${room.name} data unchanged (exact match), skipping room update`);
      } else {
        room.currentAQI = normalizedData.aqi;
        room.currentData = {
          pm25, pm10, co, so2, o3, no2,
          temperature, humidity,
          updatedAt: new Date(),
        };
        room.updatedAt = new Date();
        await room.save();

        this.broadcastRoomUpdate(room, normalizedData, 'iot', deviceName);
        logs.push(`📢 Broadcast IoT update for room ${room.name}: AQI ${room.currentAQI}`);
      }

      await new SensorData({
        roomId: room._id,
        roomName: room.name,
        buildingName: room.buildingName,
        aqi: normalizedData.aqi,
        pm25, pm10, co, so2, o3, no2,
        temperature, humidity,
        category: aqiResult.category,
        timestamp: new Date(),
        isAnomaly: iotData.isAnomaly === true,
        anomalyType: iotData.anomalyType || null,
      }).save();

      if (normalizedData.aqi == null) {
        logs.push(
          `ℹ️  IoT room ${room.name} (device ${deviceName}): tidak ada data valid — status no_data`
        );
      } else if (normalizedData.aqi > 100) {
        logs.push(
          `🚨 HIGH AQI in ${room.name} (IoT ${deviceName}): ${normalizedData.aqi} (${aqiResult.category})`
        );
      } else {
        logs.push(
          `✅ IoT room ${room.name}: AQI ${normalizedData.aqi}, ` +
            `PM2.5=${pm25}, PM10=${pm10}, ` +
            `CO=${co}, Suhu=${temperature}, RH=${humidity}`
        );
      }

      if (aqiResult.dominant) {
        const dominantLabel = this._dominantLabel(aqiResult);
        logs.push(
          `⚠️  DOMINAN ${aqiResult.dominant.toUpperCase()} in ${room.name}: AQI ${aqiResult.aqi} (${dominantLabel})`
        );
      }

      return { logs };
    } catch (error) {
      logs.push(`❌ Error updating IoT room ${room.name}: ${error.message}`);
      return { logs };
    }
  }

  async updateRoomFromIoTForce(room, iotData, deviceName) {
    const logs = [];
    try {
      if (room.demoMode) {
        logs.push(`ℹ️  Skipping room ${room.name} (demoMode active)`);
        return { logs };
      }

      const optNum = (v) =>
        typeof v === 'number' && Number.isFinite(v) && !Number.isNaN(v) ? v : null;

      const pm25 = optNum(iotData.pm25);
      const pm10 = optNum(iotData.pm10);
      const co   = optNum(iotData.co);
      const so2  = optNum(iotData.so2);
      const o3   = optNum(iotData.o3);
      const no2  = optNum(iotData.no2);
      const temperature = optNum(iotData.temperature);
      const humidity    = optNum(iotData.humidity);

      const hasError = [pm25, pm10, co, so2, o3, no2, temperature, humidity]
        .some((v) => v !== null && v < 0);

      if (hasError) {
        await this.handleDeviceError(room, deviceName, logs);
        return { logs };
      }

      const aqiResult = calculateAQI(pm25, pm10, co, so2, o3, no2);

      const normalizedData = {
        aqi: aqiResult.aqi,
        pm25, pm10, co, so2, o3, no2,
        temperature, humidity,
        category: aqiResult.category,
        dominant: aqiResult.dominant,
      };

      room.currentAQI = normalizedData.aqi;
      room.currentData = {
        pm25, pm10, co, so2, o3, no2,
        temperature, humidity,
        updatedAt: new Date(),
      };
      room.updatedAt = new Date();
      await room.save();

      this.broadcastRoomUpdate(room, normalizedData, 'iot', deviceName);
      logs.push(`📢 FORCE Broadcast IoT update for room ${room.name}: AQI ${room.currentAQI}`);

      await new SensorData({
        roomId: room._id,
        roomName: room.name,
        buildingName: room.buildingName,
        aqi: normalizedData.aqi,
        pm25, pm10, co, so2, o3, no2,
        temperature, humidity,
        category: aqiResult.category,
        timestamp: new Date(),
        isAnomaly: iotData.isAnomaly === true,
        anomalyType: iotData.anomalyType || null,
      }).save();

      if (normalizedData.aqi == null) {
        logs.push(
          `ℹ️  IoT room ${room.name} (device ${deviceName}): tidak ada data valid — status no_data`
        );
      } else if (normalizedData.aqi > 100) {
        logs.push(
          `🚨 HIGH AQI in ${room.name} (IoT ${deviceName}): ${normalizedData.aqi} (${aqiResult.category})`
        );
      } else {
        logs.push(
          `✅ IoT room ${room.name}: AQI ${normalizedData.aqi}, ` +
            `PM2.5=${pm25}, PM10=${pm10}, ` +
            `CO=${co}, Suhu=${temperature}, RH=${humidity}`
        );
      }

      if (aqiResult.dominant) {
        const dominantLabel = this._dominantLabel(aqiResult);
        logs.push(
          `⚠️  DOMINAN ${aqiResult.dominant.toUpperCase()} in ${room.name}: AQI ${aqiResult.aqi} (${dominantLabel})`
        );
      }

      return { logs };
    } catch (error) {
      logs.push(`❌ Error force-updating IoT room ${room.name}: ${error.message}`);
      return { logs };
    }
  }

  async handleDeviceError(room, deviceName, logs = []) {
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

      logs.push(
        `⚠️ IoT SENSOR ERROR in ${room.name} (device: ${deviceName}) — room retained last good value`
      );
    } catch (err) {
      logs.push(`❌ Error handling device error for ${room.name}: ${err.message}`);
    }
  }

  async forceUpdateRoom(roomId) {
    return runExclusive(async () => {
      try {
        const room = await Room.findById(roomId);
        if (!room) return { success: false, message: 'Room not found' };

        if (!room.iotDeviceId) {
          return { success: false, message: 'Room is not configured for IoT' };
        }

        const device = await IoTDevice.findById(room.iotDeviceId);
        if (!device) return { success: false, message: 'IoT device not found' };

        const response = await this._getWithRetry(device.apiEndpoint, 15000);

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

        const { logs } = await this.updateRoomFromIoTForce(room, iotData, device.name);

        // ✅ Semua console.log (satu stream) — urutan dijamin
        console.log(BORDER_TOP);
        logs.forEach((line) => console.log(line));
        console.log(BORDER_BOTTOM);

        return { success: true, data: iotData, deviceName: device.name };
      } catch (error) {
        console.log(BORDER_TOP);
        console.log(`❌ forceUpdateRoom(${roomId}) error: ${error.message}`);
        console.log(BORDER_BOTTOM);
        return { success: false, error: error.message };
      }
    });
  }

  async pollDeviceForce(device) {
    try {
      const response = await this._getWithRetry(device.apiEndpoint, 15000);

      if (response.data?.success !== true) {
        return { success: false, deviceName: device.name, error: 'Device did not return success' };
      }

      const iotData = response.data.data;
      if (!this.isValidIoTData(iotData)) {
        return { success: false, deviceName: device.name, error: 'Invalid IoT data' };
      }

      this.deviceLastData.set(device._id.toString(), iotData);

      device.status = 'online';
      device.lastUpdate = new Date();
      await device.save();

      const rooms = await Room.find({ iotDeviceId: device._id.toString() });
      const roomLogs = [];
      for (const room of rooms) {
        const { logs } = await this.updateRoomFromIoTForce(room, iotData, device.name);
        if (logs && logs.length) roomLogs.push(...logs);
      }

      return { success: true, changed: true, roomLogs };
    } catch (error) {
      device.status = 'offline';
      await device.save().catch(() => {});
      return { success: false, deviceName: device.name, error: error.message };
    }
  }

  broadcastRoomUpdate(room, data, source, deviceName = null) {
    if (this.io) {
      const updateData = {
        roomId: room._id,
        data: {
          currentAQI: room.currentAQI,
          currentData: room.currentData,
          updatedAt: room.updatedAt,
        },
        timestamp: new Date(),
        source: source,
        deviceName: deviceName,
      };

      this.io.to(room._id.toString()).emit('room-update', updateData);

      this.io.emit('dashboard-update', {
        type: 'room-data-updated',
        roomId: room._id,
        aqi: room.currentAQI,
        building: room.buildingName,
        timestamp: new Date(),
      });
    }
  }

  async forcePollAll() {
    return runExclusive(async () => {
      console.log('🔄 FORCE polling all IoT devices...');
      try {
        const devices = await IoTDevice.find({});
        if (devices.length === 0) {
          return { success: true, message: 'No IoT devices to poll', count: 0 };
        }

        const results = await Promise.allSettled(
          devices.map((d) =>
            this.pollDeviceForce(d).catch((e) => ({
              success: false,
              deviceName: d.name,
              error: e?.message || String(e),
            }))
          )
        );

        let successCount = 0;
        for (const r of results) {
          const val =
            r.status === 'fulfilled'
              ? r.value
              : { success: false, deviceName: 'unknown', error: r.reason?.message };

          console.log(BORDER_TOP);
          if (val && val.success === true) {
            successCount++;
            const lines = val.roomLogs || [];
            if (lines.length === 0) {
              console.log(
                `ℹ️  Device ${val.deviceName || 'unknown'}: no rooms updated (no rooms mapped or all demoMode)`
              );
            } else {
              lines.forEach((line) => console.log(line));
            }
          } else {
            // ✅ console.log (bukan console.error) — satu stream
            const name = val?.deviceName || 'unknown';
            const errMsg = val?.error || 'unknown error';
            console.log(`❌ Force poll failed for ${name}: ${errMsg}`);
          }
          console.log(BORDER_BOTTOM);
        }

        console.log(`✅ FORCE poll completed: ${successCount}/${devices.length}`);
        return {
          success: true,
          message: 'Force poll completed',
          polled: devices.length,
          successful: successCount,
        };
      } catch (error) {
        console.error('❌ forcePollAll error:', error.message);
        return { success: false, error: error.message };
      }
    });
  }

  getStatus() {
    return {
      isRunning: this.isRunning,
      lastUpdate: new Date(),
      nextUpdate: new Date(Date.now() + this.pollingInterval),
      socketConnected: this.io !== null,
      pollingInterval: this.pollingInterval,
      isPolling: this._polling,
    };
  }
}

const iotService = new IoTService();
module.exports = iotService;