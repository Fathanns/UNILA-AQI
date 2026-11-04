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

// GET sensor data for a room dengan data aggregation
// FIXED: route dibuat PUBLIC (authMiddleware dihapus).
// Alasan:
//  - Data historis 24 jam ini identik dengan data live yang sudah tampil
//    di dashboard publik (endpoint /rooms juga public).
//  - Visitor (tanpa login) harus bisa melihat grafik historis ruangan,
//    sama seperti admin.
//  - Sebelumnya endpoint butuh token → visitor mendapat 401 → grafik
//    kosong padahal admin normal.
router.get('/:roomId', async (req, res) => {
  try {
    const { roomId } = req.params;

    // Validasi roomId
    if (!mongoose.Types.ObjectId.isValid(roomId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid room ID format'
      });
    }

    // Ambil data 24 jam terakhir
    const now = new Date();
    const dateFilter = { timestamp: { $gte: new Date(now - 24 * 60 * 60 * 1000) } };

    // Ambil SEMUA data 24 jam (tanpa limit)
    const sensorData = await SensorData.find({
      roomId: toObjectId(roomId),
      ...dateFilter
    })
    .sort({ timestamp: 1 });

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

// GET sensor data by date untuk grafik history
// FIXED (2026): route ini sekarang mengambil data TEPAT di kelipatan
// interval (default 30 menit) dengan menggunakan $first setelah $sort,
// sehingga tiap titik merepresentasikan nilai pada awal slot
// (14:00, 14:30, 15:00, 15:30, dst) — bukan nilai di akhir slot
// (yang lebih dekat ke 14:29 / 14:59).
//
// Pipeline:
//   1. $match      — filter roomId + rentang tanggal
//   2. $addFields  — hitung slot interval (0 atau 30 untuk interval=30)
//   3. $sort       — urutkan ascending (WAJIB untuk $first yang deterministik)
//   4. $group      — per (hour, interval), ambil $first (= data di awal slot)
//   5. $sort       — urutkan hasil akhir secara kronologis
//   6. $project    — format timeLabel "HH:MM" + field yang dibutuhkan chart
router.get('/:roomId/history', async (req, res) => {
  try {
    const { roomId } = req.params;
    const { date, interval = 30 } = req.query; // interval dalam menit

    // Validasi roomId
    if (!mongoose.Types.ObjectId.isValid(roomId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid room ID format'
      });
    }

    // Parse tanggal
    let startDate, endDate;
    if (date) {
      // Jika ada tanggal spesifik
      const selectedDate = new Date(date);
      startDate = new Date(selectedDate.setHours(0, 0, 0, 0));
      endDate = new Date(selectedDate.setHours(23, 59, 59, 999));
    } else {
      // Default: hari ini
      const today = new Date();
      startDate = new Date(today.setHours(0, 0, 0, 0));
      endDate = new Date(today.setHours(23, 59, 59, 999));
    }

    const intervalNum = parseInt(interval);

    console.log(
      `📊 Fetching history data for room ${roomId} from ${startDate} to ${endDate} (interval: ${intervalNum}m)`
    );

    // Aggregation pipeline untuk data per interval
    const aggregationPipeline = [
      {
        $match: {
          roomId: toObjectId(roomId),
          timestamp: { $gte: startDate, $lte: endDate }
        }
      },
      {
        $addFields: {
          // Buat interval waktu (misal: 30 menit)
          // minute 0-29 → 0, minute 30-59 → 30 (untuk interval=30)
          timeInterval: {
            $subtract: [
              { $minute: "$timestamp" },
              { $mod: [{ $minute: "$timestamp" }, intervalNum] }
            ]
          }
        }
      },
      // FIXED: sort ascending SEBELUM $group, agar $first di bawah
      // menghasilkan nilai TEPAT di awal slot (menit :00 / :30).
      // Tanpa sort, $first mengembalikan dokumen non-deterministik.
      {
        $sort: { "timestamp": 1 }
      },
      {
        $group: {
          _id: {
            hour: { $hour: "$timestamp" },
            interval: "$timeInterval"
          },
          timestamp: { $first: "$timestamp" },
          aqi: { $first: "$aqi" },
          pm25: { $first: "$pm25" },
          pm10: { $first: "$pm10" },
          co: { $first: "$co" },
          so2: { $first: "$so2" },
          o3: { $first: "$o3" },
          no2: { $first: "$no2" },
          temperature: { $first: "$temperature" },
          humidity: { $first: "$humidity" },
          category: { $first: "$category" },
          rawData: { $push: "$$ROOT" }
        }
      },
      {
        $sort: { "timestamp": 1 }
      },
      {
        $project: {
          _id: 0,
          timestamp: 1,
          hour: "$_id.hour",
          interval: "$_id.interval",
          timeLabel: {
            $concat: [
              { $toString: "$_id.hour" },
              ":",
              {
                $cond: {
                  if: { $lt: ["$_id.interval", 10] },
                  then: "0",
                  else: ""
                }
              },
              { $toString: "$_id.interval" }
            ]
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

    // Jika tidak ada data, coba ambil data mentah
    if (aggregatedData.length === 0) {
      const rawData = await SensorData.find({
        roomId: toObjectId(roomId),
        timestamp: { $gte: startDate, $lte: endDate }
      })
      .sort({ timestamp: 1 });

      return res.json({
        success: true,
        data: rawData.map(item => ({
          ...item.toObject(),
          timeLabel: `${item.timestamp.getHours()}:${item.timestamp.getMinutes().toString().padStart(2, '0')}`
        })),
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
      startDate: startDate,
      endDate: endDate,
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

    const startOfMonth = new Date(year, month - 1, 1, 0, 0, 0, 0);
    const endOfMonth   = new Date(year, month, 0, 23, 59, 59, 999);

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
          isAnomaly: { $ne: true },   // exclude spike & error simulasi
          aqi: { $gte: 0 },           // exclude error (-1), aman untuk legacy
        },
      },
      // 2. Hitung index hari dalam minggu (Senin=1 .. Minggu=7)
      //    MongoDB $dayOfWeek: 1=Sun, 2=Mon, ..., 7=Sat
      //    Formula: ((dow + 5) % 7) + 1
      {
        $addFields: {
          dayOfWeekMonSun: {
            $add: [
              { $mod: [{ $add: [{ $dayOfWeek: '$timestamp' }, 5] }, 7] },
              1,
            ],
          },
        },
      },
      // 3. Group per tanggal (hari kalender)
      {
        $group: {
          _id: {
            day: { $dayOfMonth: '$timestamp' },
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

      // Hari dianggap punya data bila minimal AQI punya nilai valid
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