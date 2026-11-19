const axios = require('axios');
const crypto = require('crypto');
const Room = require('../models/Room');
const IoTDevice = require('../models/IoTDevice');
const SensorData = require('../models/SensorData');
const { calculateAQI } = require('../utils/aqiCalculator');

// Helper border — dipakai konsisten di semua log blok
const BORDER_TOP = '┌────────────────────────────────────────────────────────────────────────────────────';
const BORDER_BOTTOM = '└────────────────────────────────────────────────────────────────────────────────────';
const SEPARATOR = '=====================================================================================';

const LOG_TIME_ZONE = 'Asia/Jakarta';
const LOG_TIME_FORMATTER = new Intl.DateTimeFormat('en-GB', {
  timeZone: LOG_TIME_ZONE,
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
  hour12: false,
});

/** "19:47:45" dalam WIB */
function formatLogTime(date = new Date()) {
  const parts = LOG_TIME_FORMATTER.formatToParts(date);
  const pick = (type) => parts.find((p) => p.type === type)?.value ?? '00';
  return `${pick('hour')}:${pick('minute')}:${pick('second')}`;
}

/** "Senin, 18 November 2026" dalam WIB */
function formatLogDate(date = new Date()) {
  return new Intl.DateTimeFormat('id-ID', {
    timeZone: LOG_TIME_ZONE,
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  }).format(date);
}

/** "19:47:45 WIB (Senin, 18 November 2026)" */
function formatLogDateTime(date = new Date()) {
  return `${formatLogTime(date)} WIB (${formatLogDate(date)})`;
}

// Device dianggap offline bila tidak mengirim data lebih lama dari ini
const STALE_THRESHOLD_MS = 90 * 1000;
// Seberapa sering watchdog memeriksa device yang diam
const WATCHDOG_INTERVAL_MS = 15 * 1000;
// Jeda pengumpulan hasil push, agar semua device dalam satu blok tercetak sekali
const BATCH_WINDOW_MS = 1200;

// Parameter untuk pull on-demand (tombol refresh admin)
const PULL_TIMEOUT_MS = 15000;
const PULL_MAX_ATTEMPTS = 2;
const PULL_RETRY_DELAY_MS = 3000;

const KNOWN_FIELDS = [
  'aqi', 'pm25', 'pm10', 'co', 'so2', 'o3', 'no2',
  'temperature', 'humidity',
];

const optNum = (v) =>
  typeof v === 'number' && Number.isFinite(v) ? v : null;

function isValidIoTData(data) {
  if (!data || typeof data !== 'object') return false;
  return KNOWN_FIELDS.some((k) => k in data);
}

/**
 * Normalisasi endpoint untuk pencocokan: lowercase, tanpa trailing slash.
 * Mengembalikan null bila string bukan URL yang valid.
 */
function normalizeEndpoint(raw) {
  if (typeof raw !== 'string' || !raw.trim()) return null;
  try {
    const u = new URL(raw.trim());
    const path = u.pathname.replace(/\/+$/, '');
    return `${u.protocol}//${u.host}${path}`.toLowerCase();
  } catch (_) {
    return null;
  }
}

/** Segmen terakhir path, lowercase. Tetap bekerja pada endpoint yang rusak. */
function lastPathSegment(raw) {
  if (typeof raw !== 'string') return null;
  const seg = raw.trim().replace(/\/+$/, '').split('/').pop();
  return seg ? seg.toLowerCase() : null;
}

class IoTService {
  constructor() {
    this.isRunning = false;
    this.io = null;
    this._watchdog = null;
    this._batch = [];
    this._batchTimer = null;
    this.stats = {
      pushAccepted: 0,
      pushRejected: 0,
      lastPushAt: null,
    };
  }

  start(io) {
    if (this.isRunning) {
      console.log('⚠️ IoT Service is already running');
      return;
    }

    this.io = io;

    // Watchdog: tandai device offline bila sudah tidak push
    this._watchdog = setInterval(() => {
      this._markStaleDevices().catch((e) =>
        console.error('❌ Watchdog error:', e.message)
      );
    }, WATCHDOG_INTERVAL_MS);

    this.isRunning = true;
    console.log(
      `🚀 IoT Service started (mode: device push, offline setelah ${STALE_THRESHOLD_MS / 1000} detik)`
    );

    if (!process.env.INGEST_SECRET) {
      console.warn('⚠️  INGEST_SECRET belum diset — push dari device akan ditolak');
    }
  }

  stop() {
    if (this._watchdog) {
      clearInterval(this._watchdog);
      this._watchdog = null;
    }
    this.isRunning = false;
    console.log('⏹️ IoT Service stopped');
  }

  // ============================================================
  // AUTH PUSH
  // ============================================================
  verifySecret(provided) {
    const expected = process.env.INGEST_SECRET;
    if (!expected || typeof provided !== 'string') return false;

    const a = Buffer.from(provided);
    const b = Buffer.from(expected);
    if (a.length !== b.length) return false;
    return crypto.timingSafeEqual(a, b);
  }

  /**
   * Cari device berdasarkan endpoint.
   * 1) Cocok persis (setelah normalisasi).
   * 2) Bila tidak ada, cocok berdasarkan segmen terakhir URL, asalkan unik.
   */
  async findDeviceByEndpoint(endpoint) {
    const devices = await IoTDevice.find({});

    const target = normalizeEndpoint(endpoint);
    if (target) {
      const exact = devices.find(
        (d) => normalizeEndpoint(d.apiEndpoint) === target
      );
      if (exact) return exact;
    }

    const seg = lastPathSegment(endpoint);
    if (!seg) return null;

    const candidates = devices.filter(
      (d) => lastPathSegment(d.apiEndpoint) === seg
    );
    return candidates.length === 1 ? candidates[0] : null;
  }

  // ============================================================
  // PUSH — jalur utama: device → backend
  // ============================================================
  async ingestPush({ endpoint, data } = {}) {
    if (typeof endpoint !== 'string' || !endpoint.trim()) {
      this.stats.pushRejected++;
      return { success: false, status: 400, message: 'endpoint wajib diisi' };
    }

    const device = await this.findDeviceByEndpoint(endpoint);
    if (!device) {
      this.stats.pushRejected++;
      console.log(BORDER_TOP);
      console.log(`❌ Push ditolak: endpoint tidak terdaftar (${endpoint})`);
      console.log(BORDER_BOTTOM);
      return { success: false, status: 404, message: 'Device tidak terdaftar' };
    }

    if (!isValidIoTData(data)) {
      this.stats.pushRejected++;
      this._enqueue({
        deviceName: device.name,
        endpoint: device.apiEndpoint,
        success: false,
        error: 'Invalid IoT data structure',
      });
      return { success: false, status: 400, message: 'Payload data tidak valid' };
    }

    try {
      const { roomLogs, roomCount } = await this._applyDeviceReading(device, data);

      this.stats.pushAccepted++;
      this.stats.lastPushAt = new Date();

      this._enqueue({
        deviceName: device.name,
        endpoint: device.apiEndpoint,
        success: true,
        roomLogs,
      });

      return { success: true, status: 200, roomCount };
    } catch (error) {
      this.stats.pushRejected++;
      this._enqueue({
        deviceName: device.name,
        endpoint: device.apiEndpoint,
        success: false,
        error: error.message,
      });
      return { success: false, status: 500, message: 'Gagal memproses data device' };
    }
  }

  // ============================================================
  // PENERAPAN DATA KE RUANGAN (dipakai push dan pull)
  // ============================================================
  async _applyDeviceReading(device, iotData, rooms = null) {
    const now = new Date();

    await IoTDevice.updateOne(
      { _id: device._id },
      { $set: { status: 'online', lastUpdate: now, updatedAt: now } }
    );
    device.status = 'online';
    device.lastUpdate = now;

    const targets =
      rooms ?? (await Room.find({ iotDeviceId: device._id.toString() }));

    const roomLogs = [];
    for (const room of targets) {
      const { logs } = await this._applyRoomReading(room, iotData, device.name);
      roomLogs.push(...logs);
    }

    return { roomLogs, roomCount: targets.length };
  }

  async _applyRoomReading(room, iotData, deviceName) {
    const logs = [];
    try {
      if (room.demoMode) {
        logs.push(`ℹ️  Skipping room ${room.name} (demoMode active)`);
        return { logs };
      }

      const pm25 = optNum(iotData.pm25);
      const pm10 = optNum(iotData.pm10);
      const co = optNum(iotData.co);
      const so2 = optNum(iotData.so2);
      const o3 = optNum(iotData.o3);
      const no2 = optNum(iotData.no2);
      const temperature = optNum(iotData.temperature);
      const humidity = optNum(iotData.humidity);

      const hasError = [pm25, pm10, co, so2, o3, no2, temperature, humidity]
        .some((v) => v !== null && v < 0);

      if (hasError) {
        await this.handleDeviceError(room, deviceName, logs);
        return { logs };
      }

      const aqiResult = calculateAQI(pm25, pm10, co, so2, o3, no2);
      const now = new Date();

      room.currentAQI = aqiResult.aqi;
      room.currentData = {
        pm25, pm10, co, so2, o3, no2,
        temperature, humidity,
        updatedAt: now,
      };
      room.updatedAt = now;

      await Room.updateOne(
        { _id: room._id },
        {
          $set: {
            currentAQI: aqiResult.aqi,
            currentData: room.currentData,
            updatedAt: now,
          },
        }
      );

      // Broadcast lebih dulu agar layar terbarui secepat mungkin
      this.broadcastRoomUpdate(room, 'iot', deviceName);
      logs.push(`📢 Broadcast IoT update for room ${room.name}: AQI ${room.currentAQI}`);

      await SensorData.create({
        roomId: room._id,
        roomName: room.name,
        buildingName: room.buildingName,
        aqi: aqiResult.aqi,
        pm25, pm10, co, so2, o3, no2,
        temperature, humidity,
        category: aqiResult.category,
        timestamp: now,
        isAnomaly: iotData.isAnomaly === true,
        anomalyType: iotData.anomalyType || null,
      });

      if (aqiResult.aqi == null) {
        logs.push(
          `ℹ️  IoT room ${room.name} (device ${deviceName}): tidak ada data valid — status no_data`
        );
      } else if (aqiResult.aqi > 100) {
        logs.push(
          `🚨 HIGH AQI in ${room.name} (IoT ${deviceName}): ${aqiResult.aqi} (${aqiResult.category})`
        );
      } else {
        logs.push(
          `✅ IoT room ${room.name}: AQI ${aqiResult.aqi}, ` +
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

  async handleDeviceError(room, deviceName, logs = []) {
    try {
      await SensorData.create({
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
      });

      logs.push(
        `⚠️ IoT SENSOR ERROR in ${room.name} (device: ${deviceName}) — room retained last good value`
      );
    } catch (err) {
      logs.push(`❌ Error handling device error for ${room.name}: ${err.message}`);
    }
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

  // ============================================================
  // REALTIME — broadcast ke semua client (dashboard, kelola ruangan, detail)
  // ============================================================
  broadcastRoomUpdate(room, source = 'iot', deviceName = null) {
    if (!this.io) return;

    const roomId = room._id.toString();
    const cd = room.currentData || {};

    this.io.emit('dashboard-update', {
      type: 'room-data-updated',
      roomId,
      aqi: room.currentAQI,
      building: room.buildingName,
      timestamp: new Date(),
      source,
      deviceName,
      room: {
        id: roomId,
        name: room.name,
        buildingId: room.building ? room.building.toString() : null,
        buildingName: room.buildingName,
        currentAQI: room.currentAQI,
        currentData: {
          pm25: cd.pm25 ?? null,
          pm10: cd.pm10 ?? null,
          co: cd.co ?? null,
          so2: cd.so2 ?? null,
          o3: cd.o3 ?? null,
          no2: cd.no2 ?? null,
          temperature: cd.temperature ?? null,
          humidity: cd.humidity ?? null,
          updatedAt: cd.updatedAt ?? null,
        },
        createdAt: room.createdAt,
        updatedAt: room.updatedAt,
      },
    });
  }

  // ============================================================
  // WATCHDOG — device yang diam dianggap offline
  // ============================================================
  async _markStaleDevices() {
    const cutoff = new Date(Date.now() - STALE_THRESHOLD_MS);

    const stale = await IoTDevice.find(
      { status: 'online', lastUpdate: { $lt: cutoff } },
      'name'
    );
    if (stale.length === 0) return;

    await IoTDevice.updateMany(
      { _id: { $in: stale.map((d) => d._id) } },
      { $set: { status: 'offline', updatedAt: new Date() } }
    );

    stale.forEach((d) => {
      console.log(
        `⚠️  Device ${d.name} tidak mengirim data > ${STALE_THRESHOLD_MS / 1000} detik → offline`
      );
    });
  }

  /**
   * Dipakai oleh GET /api/iot-devices?live=true.
   * Status dihitung dari waktu push terakhir, tanpa menghubungi device.
   */
  async checkDeviceStatus(devices) {
    if (!devices || devices.length === 0) return [];

    const cutoff = Date.now() - STALE_THRESHOLD_MS;
    const updates = [];
    const ops = [];

    for (const d of devices) {
      const last = d.lastUpdate ? new Date(d.lastUpdate).getTime() : 0;
      const next = last >= cutoff ? 'online' : 'offline';
      updates.push({ id: d._id.toString(), status: next });

      if (d.status !== next) {
        ops.push({
          updateOne: {
            filter: { _id: d._id },
            update: { $set: { status: next } },
          },
        });
      }
    }

    if (ops.length > 0) {
      try {
        await IoTDevice.bulkWrite(ops);
      } catch (err) {
        console.error('❌ bulkWrite status check failed:', err.message);
      }
    }

    return updates;
  }

  // ============================================================
  // PULL ON-DEMAND — hanya dipakai tombol refresh admin
  // ============================================================
  async _getWithRetry(url, timeoutMs = PULL_TIMEOUT_MS) {
    let lastError;
    for (let attempt = 1; attempt <= PULL_MAX_ATTEMPTS; attempt++) {
      try {
        return await axios.get(url, { timeout: timeoutMs });
      } catch (err) {
        lastError = err;
        if (attempt < PULL_MAX_ATTEMPTS) {
          await new Promise((r) => setTimeout(r, PULL_RETRY_DELAY_MS));
        }
      }
    }
    throw lastError;
  }

  /**
   * Tarik data dari device sekali. Status device tidak diubah bila gagal,
   * karena device mungkin tetap mengirim push.
   */
  async pullDevice(device, rooms = null) {
    const base = { deviceName: device.name, endpoint: device.apiEndpoint };
    try {
      const response = await this._getWithRetry(device.apiEndpoint);

      if (response.data?.success !== true) {
        return { ...base, success: false, error: 'Device did not return success' };
      }

      const iotData = response.data.data;
      if (!isValidIoTData(iotData)) {
        return { ...base, success: false, error: 'Invalid IoT data structure' };
      }

      const { roomLogs } = await this._applyDeviceReading(device, iotData, rooms);
      return { ...base, success: true, roomLogs, iotData };
    } catch (error) {
      return { ...base, success: false, error: error.message };
    }
  }

  async forcePollAll() {
    try {
      const devices = await IoTDevice.find({});
      if (devices.length === 0) {
        console.log('ℹ️ No IoT devices to poll');
        return { success: true, message: 'No IoT devices to poll', count: 0 };
      }

      const results = await Promise.all(devices.map((d) => this.pullDevice(d)));
      this._printBatch(results);

      const successful = results.filter((r) => r.success).length;
      return {
        success: true,
        message: 'Force poll completed',
        polled: devices.length,
        successful,
      };
    } catch (error) {
      console.error('❌ forcePollAll error:', error.message);
      return { success: false, error: error.message };
    }
  }

  /** Alias untuk kompatibilitas (dipanggil dari socket 'request-refresh'). */
  async pollAllIoTDevices() {
    return this.forcePollAll();
  }

  async forceUpdateRoom(roomId) {
    try {
      const room = await Room.findById(roomId);
      if (!room) return { success: false, message: 'Room not found' };

      if (!room.iotDeviceId) {
        return { success: false, message: 'Room is not configured for IoT' };
      }

      const device = await IoTDevice.findById(room.iotDeviceId);
      if (!device) return { success: false, message: 'IoT device not found' };

      const result = await this.pullDevice(device, [room]);
      this._printBatch([result]);

      if (!result.success) {
        return { success: false, message: result.error };
      }
      return { success: true, data: result.iotData, deviceName: device.name };
    } catch (error) {
      console.log(BORDER_TOP);
      console.log(`❌ forceUpdateRoom(${roomId}) error: ${error.message}`);
      console.log(BORDER_BOTTOM);
      return { success: false, error: error.message };
    }
  }

  // ============================================================
  // LOGGING — format terminal dipertahankan
  // ============================================================
  _enqueue(result) {
    this._batch.push(result);
    if (!this._batchTimer) {
      this._batchTimer = setTimeout(() => this._flushBatch(), BATCH_WINDOW_MS);
    }
  }

  _flushBatch() {
    const batch = this._batch;
    this._batch = [];
    this._batchTimer = null;
    if (batch.length > 0) this._printBatch(batch);
  }

  _printBatch(results) {
    const total = results.length;
    const successful = results.filter((r) => r.success).length;

    console.log(`🔄 Polling ${total} IoT devices...`);
    results.forEach((r) => {
      console.log(`📡 Polling device: ${r.deviceName} (${r.endpoint})`);
    });

    results.forEach((r) => {
      console.log(BORDER_TOP);
      if (r.success) {
        const lines = r.roomLogs || [];
        if (lines.length === 0) {
          console.log(
            `ℹ️  Device ${r.deviceName}: no rooms updated (no rooms mapped or all demoMode)`
          );
        } else {
          lines.forEach((line) => console.log(line));
        }
      } else {
        console.log(`❌ Error polling device ${r.deviceName}: ${r.error || 'unknown error'}`);
      }
      console.log(BORDER_BOTTOM);
    });

    console.log(`\n✅ IoT polling completed: ${successful}/${total} successful`);
    console.log(`🕒 Updated at ${formatLogDateTime()} WIB`);
    console.log(`\n${SEPARATOR}\n`);
  }

  getStatus() {
    return {
      isRunning: this.isRunning,
      mode: 'push',
      lastUpdate: new Date(),
      socketConnected: this.io !== null,
      staleThresholdMs: STALE_THRESHOLD_MS,
      isPolling: this._batchTimer !== null,
      stats: { ...this.stats },
    };
  }
}

const iotService = new IoTService();
module.exports = iotService;