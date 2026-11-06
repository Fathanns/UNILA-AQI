const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const SensorData = require('../models/SensorData');

// Helper function untuk convert string ke ObjectId
const toObjectId = (id) => {
  try {
    return new mongoose.Types.ObjectId(id);
  } catch (error) {
    return null;
  }
};

// ============================================================
// Helper: Format tanggal WIB
// ============================================================
const WIB_OFFSET_MS = 7 * 60 * 60 * 1000;

/** Kembalikan tanggal hari ini (WIB) dalam format YYYY-MM-DD */
function getTodayWIBDateStr() {
  const now = new Date();
  const wib = new Date(now.getTime() + WIB_OFFSET_MS);
  return wib.toISOString().split('T')[0];
}

/** Format timestamp menjadi "HH:MM" dalam zona WIB */
function formatWIBTimeLabel(timestamp) {
  const wibDate = new Date(new Date(timestamp).getTime() + WIB_OFFSET_MS);
  const hh = wibDate.getUTCHours().toString().padStart(2, '0');
  const mm = wibDate.getUTCMinutes().toString().padStart(2, '0');
  return `${hh}:${mm}`;
}

// ============================================================
// GET sensor data for a room (24 jam terakhir)
// ============================================================
router.get('/:roomId', async (req, res) => {
  try {
    const { roomId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(roomId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid room ID format'
      });
    }

    // Ambil data 24 jam terakhir
    const now = new Date();
    const dateFilter = { timestamp: { $gte: new Date(now - 24 * 60 * 60 * 1000) } };

    const sensorData = await SensorData.find({
      roomId: toObjectId(roomId),
      ...dateFilter
    }).sort({ timestamp: 1 });

    res.json({
      success: true,
      data: sensorData,
      count: sensorData.length,
      message: '24 hours data loaded'
    });
  } catch (error) {
    console.error('Error fetching sensor data:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching sensor data',
      error: error.message
    });
  }
});

// ============================================================
// GET sensor data by date untuk grafik history (WIB aware)
// ============================================================
// FIXED (2026-11):
//   - Query rentang tanggal menggunakan zona WIB (+07:00)
//     sehingga pukul 00:00 WIB s/d 23:59 WIB terambil penuh.
//   - $hour & $minute diberi timezone "+07:00" agar label
//     chart menunjukkan jam WIB, bukan UTC.
//   - Fallback raw data juga diformat ke WIB (bukan UTC).
//   - ✅ BARU: timestamp hasil group di-rebuild via $dateFromParts
//     sehingga SELALU jatuh tepat di menit :00 atau :30 (detik = 0).
//     Ini mencegah label aneh seperti 16:46 di chart frontend.
//
// Pipeline:
//   1. $match      — filter roomId + rentang tanggal WIB
//   2. $addFields  — hitung slot interval (WIB)
//   3. $sort       — urutkan ascending (WAJIB untuk $first)
//   4. $group      — per (hour, interval), ambil $first
//   5. $sort       — urutkan hasil akhir kronologis
//   6. $project    — rebuild timestamp ke slot (detik = 0),
//                    format timeLabel "HH:MM" (WIB)
// ============================================================
router.get('/:roomId/history', async (req, res) => {
  try {
    const { roomId } = req.params;
    const { date, interval = 30 } = req.query;

    if (!mongoose.Types.ObjectId.isValid(roomId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid room ID format'
      });
    }

    // ✅ FIX: Waktu WIB (UTC+7)
    let startDate, endDate;
    if (date) {
      startDate = new Date(`${date}T00:00:00.000+07:00`);
      endDate = new Date(`${date}T23:59:59.999+07:00`);
    } else {
      const wibDate = getTodayWIBDateStr();
      startDate = new Date(`${wibDate}T00:00:00.000+07:00`);
      endDate = new Date(`${wibDate}T23:59:59.999+07:00`);
    }

    const intervalNum = parseInt(interval, 10);
    if (isNaN(intervalNum) || intervalNum <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Parameter interval tidak valid',
      });
    }

    console.log(
      `📊 Fetching history data for room ${roomId} from ${startDate.toISOString()} to ${endDate.toISOString()} (interval: ${intervalNum}m)`
    );

    const aggregationPipeline = [
      {
        $match: {
          roomId: toObjectId(roomId),
          timestamp: { $gte: startDate, $lte: endDate }
        }
      },
      {
        $addFields: {
          // ✅ FIX: timezone "+07:00" agar $minute ikut WIB
          timeInterval: {
            $subtract: [
              { $minute: { date: '$timestamp', timezone: '+07:00' } },
              {
                $mod: [
                  { $minute: { date: '$timestamp', timezone: '+07:00' } },
                  intervalNum
                ]
              }
            ]
          }
        }
      },
      {
        $sort: { timestamp: 1 }
      },
      {
        $group: {
          _id: {
            hour: { $hour: { date: '$timestamp', timezone: '+07:00' } },
            interval: '$timeInterval'
          },
          timestamp: { $first: '$timestamp' },
          aqi: { $first: '$aqi' },
          pm25: { $first: '$pm25' },
          pm10: { $first: '$pm10' },
          co: { $first: '$co' },
          so2: { $first: '$so2' },
          o3: { $first: '$o3' },
          no2: { $first: '$no2' },
          temperature: { $first: '$temperature' },
          humidity: { $first: '$humidity' },
          category: { $first: '$category' },
          rawData: { $push: '$$ROOT' }
        }
      },
      {
        $sort: { timestamp: 1 }
      },
      {
        $project: {
          _id: 0,
          // ✅ FIX: rebuild timestamp dari slot (hour + interval, detik = 0)
          // sehingga selalu jatuh tepat di menit :00 atau :30.
          // Frontend history_chart.dart menggunakan field ini untuk
          // menampilkan label jam di sumbu-X.
          timestamp: {
            $dateFromParts: {
              year:   { $year:   { date: '$timestamp', timezone: '+07:00' } },
              month:  { $month:  { date: '$timestamp', timezone: '+07:00' } },
              day:    { $dayOfMonth: { date: '$timestamp', timezone: '+07:00' } },
              hour:   '$_id.hour',
              minute: '$_id.interval',
              second: 0,
              millisecond: 0,
              timezone: '+07:00',
            },
          },
          hour: '$_id.hour',
          interval: '$_id.interval',
          timeLabel: {
            $concat: [
              {
                $cond: {
                  if: { $lt: ['$_id.hour', 10] },
                  then: { $concat: ['0', { $toString: '$_id.hour' }] },
                  else: { $toString: '$_id.hour' },
                },
              },
              ':',
              {
                $cond: {
                  if: { $lt: ['$_id.interval', 10] },
                  then: { $concat: ['0', { $toString: '$_id.interval' }] },
                  else: { $toString: '$_id.interval' },
                },
              },
            ],
          },
          aqi: 1,
          pm25: 1,
          pm10: 1,
          co: 1,
          so2: 1,
          o3: 1,
          no2: 1,
          temperature: 1,
          humidity: 1,
          category: 1,
        }
      }
    ];

    const aggregatedData = await SensorData.aggregate(aggregationPipeline);

    // Fallback: jika tidak ada data agregasi, ambil data mentah
    if (aggregatedData.length === 0) {
      const rawData = await SensorData.find({
        roomId: toObjectId(roomId),
        timestamp: { $gte: startDate, $lte: endDate }
      }).sort({ timestamp: 1 });

      return res.json({
        success: true,
        // ✅ FIX: bulatkan timestamp ke slot 30 menit terdekat (detik = 0)
        // dan format timeLabel ke WIB (bukan getHours() yang UTC).
        data: rawData.map((item) => {
          const obj = item.toObject();

          const wibMs = new Date(item.timestamp).getTime() + WIB_OFFSET_MS;
          const wibDate = new Date(wibMs);
          const roundedMinute = wibDate.getUTCMinutes() < 30 ? 0 : 30;
          const roundedWib = new Date(Date.UTC(
            wibDate.getUTCFullYear(),
            wibDate.getUTCMonth(),
            wibDate.getUTCDate(),
            wibDate.getUTCHours(),
            roundedMinute,
            0,
            0,
          ));

          obj.timestamp = new Date(roundedWib.getTime() - WIB_OFFSET_MS);
          obj.timeLabel = formatWIBTimeLabel(obj.timestamp);
          return obj;
        }),
        aggregated: false,
        count: rawData.length,
        message: 'Raw data loaded'
      });
    }

    res.json({
      success: true,
      data: aggregatedData,
      aggregated: true,
      count: aggregatedData.length,
      startDate,
      endDate,
      message: 'Aggregated history data loaded'
    });
  } catch (error) {
    console.error('Error fetching history data:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching history data',
      error: error.message
    });
  }
});

// ============================================================
// GET monthly trend (WIB aware)
// ============================================================
router.get('/:roomId/monthly', async (req, res) => {
  try {
    const { roomId } = req.params;
    const year  = parseInt(req.query.year, 10);
    const month = parseInt(req.query.month, 10);

    if (!mongoose.Types.ObjectId.isValid(roomId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid room ID format',
      });
    }

    if (isNaN(year) || year < 2000 || year > 2100) {
      return res.status(400).json({
        success: false,
        message: 'Parameter year tidak valid',
      });
    }

    if (isNaN(month) || month < 1 || month > 12) {
      return res.status(400).json({
        success: false,
        message: 'Parameter month tidak valid (1-12)',
      });
    }

    // ✅ FIX: gunakan zona WIB agar cut-off tanggal akurat
    const startOfMonth = new Date(
      `${year}-${String(month).padStart(2, '0')}-01T00:00:00.000+07:00`
    );
    // Hari terakhir bulan: tanggal 0 dari bulan berikutnya
    const lastDay = new Date(year, month, 0).getDate();
    const endOfMonth = new Date(
      `${year}-${String(month).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}T23:59:59.999+07:00`
    );

    console.log(
      `📊 Monthly trend → room ${roomId} | ${year}-${String(month).padStart(2, '0')} | ` +
      `${startOfMonth.toISOString()} → ${endOfMonth.toISOString()}`
    );

    const allParams = [
      'aqi', 'pm25', 'pm10', 'co', 'so2', 'o3', 'no2',
      'temperature', 'humidity',
    ];

    // Accumulator tahap 1: per tanggal
    const dailyAcc = {};
    allParams.forEach((p) => {
      dailyAcc[`daily_max_${p}`] = { $max: `$${p}` };
      dailyAcc[`daily_avg_${p}`] = { $avg: `$${p}` };
      dailyAcc[`daily_min_${p}`] = { $min: `$${p}` };
    });

    // Accumulator tahap 2: per hari-dalam-minggu
    const monthlyAcc = { weekCount: { $sum: 1 } };
    allParams.forEach((p) => {
      monthlyAcc[`max_${p}`] = { $max: `$daily_max_${p}` };
      monthlyAcc[`avg_${p}`] = { $avg: `$daily_avg_${p}` };
      monthlyAcc[`min_${p}`] = { $min: `$daily_min_${p}` };
    });

    const pipeline = [
      // 1. Filter: room + rentang bulan + BUKAN anomali + BUKAN error (-1)
      {
        $match: {
          roomId: toObjectId(roomId),
          timestamp: { $gte: startOfMonth, $lte: endOfMonth },
          isAnomaly: { $ne: true },
          aqi: { $gte: 0 },
        },
      },
      // 2. Hitung index hari dalam minggu (Senin=1 .. Minggu=7) — WIB
      {
        $addFields: {
          dayOfWeekMonSun: {
            $add: [
              {
                $mod: [
                  {
                    $add: [
                      { $dayOfWeek: { date: '$timestamp', timezone: '+07:00' } },
                      5,
                    ],
                  },
                  7,
                ],
              },
              1,
            ],
          },
        },
      },
      // 3. Group per tanggal (hari kalender WIB)
      {
        $group: {
          _id: {
            day: { $dayOfMonth: { date: '$timestamp', timezone: '+07:00' } },
            dow: '$dayOfWeekMonSun',
          },
          ...dailyAcc,
        },
      },
      // 4. Group per hari-dalam-minggu
      {
        $group: {
          _id: '$_id.dow',
          ...monthlyAcc,
        },
      },
      // 5. Urutkan Senin..Minggu
      { $sort: { _id: 1 } },
    ];

    const rawResult = await SensorData.aggregate(pipeline);

    const dayNames = [
      'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
    ];

    const round1 = (v) =>
      typeof v === 'number' && !Number.isNaN(v)
        ? Math.round(v * 10) / 10
        : null;

    const days = [];
    for (let i = 1; i <= 7; i++) {
      const found = rawResult.find((r) => r._id === i);

      const values = {};
      allParams.forEach((p) => {
        values[p] = {
          max: found ? round1(found[`max_${p}`]) : null,
          avg: found ? round1(found[`avg_${p}`]) : null,
          min: found ? round1(found[`min_${p}`]) : null,
        };
      });

      const hasData = values.aqi.max !== null;

      days.push({
        day: i,
        dayName: dayNames[i - 1],
        hasData,
        weekCount: found?.weekCount ?? 0,
        values,
      });
    }

    res.json({
      success: true,
      year,
      month,
      roomId,
      startDate: startOfMonth,
      endDate: endOfMonth,
      days,
      message: 'Monthly trend data loaded',
    });
  } catch (error) {
    console.error('Error fetching monthly trend:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching monthly trend',
      error: error.message,
    });
  }
});

module.exports = router;