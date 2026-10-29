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
          // FIXED: $first (bukan $last) agar titik merepresentasikan
          // nilai pada awal slot — cocok dengan label "14:00", "14:30".
          timestamp: { $first: "$timestamp" },
          aqi: { $first: "$aqi" },
          pm25: { $first: "$pm25" },
          pm10: { $first: "$pm10" },
          co2: { $first: "$co2" },
          temperature: { $first: "$temperature" },
          humidity: { $first: "$humidity" },
          category: { $first: "$category" },
          // Simpan semua data mentah slot (untuk tooltip / audit)
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
          co2: 1,
          temperature: 1,
          humidity: 1,
          category: 1,
          rawData: 1
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

module.exports = router;