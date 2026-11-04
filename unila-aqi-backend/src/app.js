const mongoose = require('mongoose');
const express = require('express');
const cors = require('cors');
const http = require('http');
const socketIo = require('socket.io');
const simulationService = require('./services/simulationService');
const iotService = require('./services/iotService');
const { seedSampleData } = require('./utils/seedData');
const seedRoutes = require('./routes/seedRoutes');
const testRoutes = require('./routes/testRoutes');
const buildingRoutes = require('./routes/buildingRoutes');
const roomRoutes = require('./routes/roomRoutes');
const iotDeviceRoutes = require('./routes/iotDeviceRoutes');
const sensorDataRoutes = require('./routes/sensorDataRoutes');

require('dotenv').config();

const User = require('./models/User');
const Building = require('./models/Building');
const Room = require('./models/Room');
const SensorData = require('./models/SensorData');
const IoTDevice = require('./models/IoTDevice');
const authRoutes = require('./routes/authRoutes');
const { authMiddleware } = require('./middleware/authMiddleware');

// ============================================================
// 1) VALIDASI ENVIRONMENT VARIABLE (FAIL FAST)
// ============================================================
// Di Render / production, kita tidak mau server jalan tanpa
// konfigurasi yang benar. Lebih baik crash di awal dengan pesan
// jelas, daripada 500 error yang membingungkan nanti.
if (!process.env.JWT_SECRET) {
  console.error('❌ FATAL: JWT_SECRET is not defined in environment variables');
  process.exit(1);
}

if (!process.env.MONGODB_URI) {
  console.error('❌ FATAL: MONGODB_URI is not defined in environment variables');
  process.exit(1);
}

const PORT = process.env.PORT || 5000;
const HOST = '0.0.0.0'; // ✅ WAJIB untuk Render / Docker / VPS

// ============================================================
// 2) SETUP EXPRESS + HTTP SERVER + SOCKET.IO
// ============================================================
const app = express();
const server = http.createServer(app);

// Handler error di level HTTP server (mis. port bentrok)
server.on('error', (err) => {
  console.error('❌ Server error:', err.message);
  if (err.code === 'EADDRINUSE') {
    console.error(`   Port ${PORT} sudah digunakan.`);
    console.error('   Hentikan proses lain di port tersebut atau ubah PORT di .env');
  }
  process.exit(1);
});

const io = socketIo(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    credentials: true,
  },
  // ✅ Timeout lebih longgar untuk koneksi mobile (jaringan tidak stabil)
  pingTimeout: 60000,
  pingInterval: 25000,
});

// ============================================================
// 3) MIDDLEWARE
// ============================================================
app.use(cors());
app.use(express.json({ limit: '1mb' })); // batasi payload agar tidak disalahgunakan
app.set('socketio', io);

// ============================================================
// 4) ROUTES
// ============================================================
app.use('/api/auth', authRoutes);
app.use('/api/seed', seedRoutes);
app.use('/api/test', testRoutes);
app.use('/api/buildings', buildingRoutes);
app.use('/api/rooms', roomRoutes);
app.use('/api/iot-devices', iotDeviceRoutes);
app.use('/api/sensor-data', sensorDataRoutes);

// Basic route (health check)
app.get('/', (req, res) => {
  res.json({
    message: 'UNILA AQI Backend API is running',
    database: mongoose.connection.readyState === 1 ? 'Connected' : 'Disconnected',
    timestamp: new Date(),
    socketIO: 'Active',
    env: process.env.NODE_ENV || 'development',
  });
});

app.get('/api/simple-test', (req, res) => {
  res.json({
    message: 'Simple test endpoint working',
    timestamp: new Date(),
    status: 'OK',
    dbConnected: mongoose.connection.readyState === 1,
    socketConnected: io !== undefined,
  });
});

// ============================================================
// 5) SOCKET.IO CONNECTION HANDLER
// ============================================================
io.on('connection', (socket) => {
  console.log(`🔌 New client connected: ${socket.id}`);

  socket.on('join-room', (roomId) => {
    socket.join(roomId);
    console.log(`📡 Socket ${socket.id} joined room: ${roomId}`);
    socket.emit('room-joined', {
      roomId: roomId,
      message: `Connected to room ${roomId}`,
      timestamp: new Date(),
    });
  });

  socket.on('leave-room', (roomId) => {
    socket.leave(roomId);
    console.log(`📡 Socket ${socket.id} left room: ${roomId}`);
  });

  socket.on('subscribe-dashboard', () => {
    socket.join('dashboard');
    console.log(`📊 Socket ${socket.id} subscribed to dashboard updates`);
    socket.emit('dashboard-subscribed', {
      message: 'Subscribed to dashboard updates',
      timestamp: new Date(),
    });
  });

  socket.on('unsubscribe-dashboard', () => {
    socket.leave('dashboard');
    console.log(`📊 Socket ${socket.id} unsubscribed from dashboard`);
  });

  socket.on('subscribe-room-updates', (roomId) => {
    socket.join(`room-updates-${roomId}`);
    console.log(`📡 Socket ${socket.id} subscribed to room ${roomId} updates`);
  });

  socket.on('request-refresh', (data) => {
    const roomId = data?.roomId;
    console.log(`🔄 Socket ${socket.id} requested refresh${roomId ? ` for room ${roomId}` : ''}`);

    if (roomId) {
      socket.to(roomId).emit('room-refresh-requested', {
        requestedBy: socket.id,
        timestamp: new Date(),
      });
    } else {
      simulationService.updateAllRooms().catch((e) => {
        console.error('❌ simulationService.updateAllRooms error:', e.message);
      });
      iotService.pollAllIoTDevices().catch((e) => {
        console.error('❌ iotService.pollAllIoTDevices error:', e.message);
      });

      io.emit('refresh-started', {
        requestedBy: socket.id,
        timestamp: new Date(),
      });
    }

    socket.emit('refresh-acknowledged', {
      message: 'Refresh request received',
      timestamp: new Date(),
    });
  });

  socket.on('disconnect', (reason) => {
    console.log(`🔌 Client disconnected: ${socket.id} (reason: ${reason})`);
    socket.to('dashboard').emit('client-disconnected', {
      socketId: socket.id,
      timestamp: new Date(),
      reason: reason,
    });
  });

  socket.on('ping', (data) => {
    const clientTime = data?.timestamp;
    socket.emit('pong', {
      serverTime: new Date(),
      clientTime: clientTime,
      latency: clientTime ? Date.now() - new Date(clientTime).getTime() : null,
    });
  });

  socket.emit('connected', {
    socketId: socket.id,
    message: 'Connected to UNILA AQI WebSocket server',
    timestamp: new Date(),
    serverInfo: {
      name: 'UNILA AQI Backend',
      version: '1.0.0',
      features: ['real-time-updates', 'room-monitoring', 'dashboard-updates'],
    },
  });
});

// ============================================================
// 6) HELPER BROADCAST (opsional — dipakai modul lain bila perlu)
// ============================================================
const broadcastRoomUpdate = (roomId, data) => {
  if (io) {
    io.to(roomId).emit('room-update', {
      roomId,
      data,
      timestamp: new Date(),
    });
    console.log(`📢 Broadcast update to room ${roomId}: AQI ${data.aqi}`);
  }
};

const broadcastToAll = (event, data) => {
  if (io) {
    io.emit(event, data);
  }
};

module.exports = { broadcastRoomUpdate, broadcastToAll };

// ============================================================
// 7) SEED ADMIN & SYNC HELPERS
// ============================================================
async function syncBuildingNames() {
  try {
    console.log('🔄 Syncing building names in rooms...');
    const rooms = await Room.find().populate('building', 'name');
    let updatedCount = 0;

    for (const room of rooms) {
      if (room.building && room.buildingName !== room.building.name) {
        room.buildingName = room.building.name;
        await room.save();
        updatedCount++;
      }
    }

    if (updatedCount > 0) {
      console.log(`✅ Synced building names for ${updatedCount} rooms`);
    } else {
      console.log('✅ All room building names are already synced');
    }
  } catch (error) {
    console.error('❌ Error syncing building names:', error.message);
  }
}

const seedInitialAdmin = async () => {
  try {
    const { hashPassword } = require('./utils/auth');
    const adminExists = await User.findOne({ role: 'admin' });

    if (!adminExists) {
      const hashedPassword = await hashPassword('admin123');
      const admin = new User({
        username: 'admin',
        password: hashedPassword,
        email: 'admin@unila-aqi.ac.id',
        role: 'admin',
      });

      await admin.save();
      console.log('✅ Initial admin user created');
      console.log('👤 Username: admin');
      console.log('🔑 Password: admin123');
    } else {
      console.log('✅ Admin user already exists');
    }
  } catch (error) {
    console.error('❌ Error seeding admin:', error);
  }
};

// ============================================================
// 8) ENDPOINT FORCE-REFRESH (butuh auth)
// ============================================================
app.post('/api/force-refresh', authMiddleware, async (req, res) => {
  try {
    await simulationService.forceUpdate();
    await iotService.forcePollAll();

    res.json({
      success: true,
      message: 'Force refresh completed for both services',
      timestamp: new Date(),
      services: {
        simulation: 'Forced update completed',
        iot: 'Forced polling completed',
      },
    });
  } catch (error) {
    console.error('❌ Force refresh error:', error);
    res.status(500).json({
      success: false,
      message: 'Gagal melakukan refresh',
      error: error.message,
    });
  }
});

// ============================================================
// 9) 404 & ERROR HANDLER (setelah semua route)
// ============================================================
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: 'Endpoint not found',
    path: req.originalUrl,
    method: req.method,
  });
});

app.use((err, req, res, next) => {
  console.error('❌ Unhandled error:', err.message);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Internal server error',
  });
});

// ============================================================
// 10) MONGODB CONNECT + START SERVER
// ============================================================
// ✅ KUNCI PERUBAHAN:
//   - Semua inisialisasi (syncIndexes, seed, start service)
//     dijalankan SETELAH MongoDB tersambung.
//   - server.listen dipanggil SETELAH semuanya siap.
//   - Kalau koneksi DB gagal, proses keluar (exit 1) sehingga
//     Render tahu deploy gagal dan tidak meneruskan trafik.

mongoose
  .connect(process.env.MONGODB_URI, {
    serverSelectionTimeoutMS: 15000, // toleransi cold start Atlas
  })
  .then(async () => {
    console.log('✅ Connected to MongoDB Atlas');
    console.log(`📊 Database: ${mongoose.connection.db.databaseName}`);
    console.log(`📍 Host: ${mongoose.connection.host}`);

    // Drop index lama & buat ulang yang sparse untuk Building.code
    try {
      await Building.syncIndexes();
      console.log('✅ Building indexes synced (code sparse)');
    } catch (syncErr) {
      console.error('⚠️  Building index sync warning:', syncErr.message);
    }

    // Seed admin & sync building names
    await seedInitialAdmin();
    await syncBuildingNames();

    // Seed sample buildings & rooms jika kosong
    const buildingCount = await Building.countDocuments();
    if (buildingCount === 0) {
      console.log('🌱 Seeding sample data...');
      await seedSampleData();
    } else {
      console.log(`📊 Database already has ${buildingCount} buildings, skipping sample seeding`);
    }

    // Start background services
    simulationService.start(io);
    iotService.start(io);

    console.log('✅ All services started');
    console.log('   - Simulation Service: ACTIVE (30 second intervals)');
    console.log('   - IoT Service: ACTIVE (30 second intervals)');

    // ✅ START SERVER SETELAH SEMUA SIAP
    server.listen(PORT, HOST, () => {
      console.log('═══════════════════════════════════════════════════════');
      console.log(`🚀 Server running on http://${HOST}:${PORT}`);
      console.log(`🌐 API Base URL: /api`);
      console.log(`📡 WebSocket ready`);
      console.log(`🔌 Socket.IO ready for real-time updates`);
      console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
      console.log('═══════════════════════════════════════════════════════');
    });
  })
  .catch((err) => {
    console.error('❌ MongoDB connection error:', err.message);
    const uri = process.env.MONGODB_URI || '';
    const maskedUri = uri.replace(/:[^:@]*@/, ':****@');
    console.error('Connection string:', maskedUri);
    console.error('⚠️  Server tidak akan dijalankan sampai DB tersambung.');
    process.exit(1); // ✅ Render akan tahu deploy gagal
  });

// ============================================================
// 11) GRACEFUL SHUTDOWN (penting untuk Render)
// ============================================================
// Render mengirim SIGTERM saat:
//   - deploy versi baru (container lama dimatikan)
//   - manual restart
//   - scale down
// Kita beri waktu 10 detik untuk menutup koneksi DB & socket,
// lalu exit. Tanpa ini, Render akan force-kill setelah 30 detik
// dan mungkin menyisakan koneksi "zombie" di MongoDB Atlas.

let isShuttingDown = false;

const shutdown = async (signal) => {
  if (isShuttingDown) return;
  isShuttingDown = true;

  console.log(`\n⚠️  Received ${signal}. Shutting down gracefully...`);

  // 1) Stop background services
  try {
    simulationService.stop();
    iotService.stop();
    console.log('⏹️  Background services stopped');
  } catch (e) {
    console.error('⚠️  Error stopping services:', e.message);
  }

  // 2) Tutup Socket.IO
  try {
    io.close(() => console.log('🔌 Socket.IO closed'));
  } catch (e) {
    console.error('⚠️  Error closing Socket.IO:', e.message);
  }

  // 3) Tutup HTTP server
  server.close(() => {
    console.log('🛑 HTTP server closed');
  });

  // 4) Disconnect MongoDB
  try {
    await mongoose.disconnect();
    console.log('🔌 MongoDB disconnected');
  } catch (e) {
    console.error('⚠️  Error disconnecting MongoDB:', e.message);
  }

  // 5) Paksa exit setelah 10 detik jika masih menggantung
  setTimeout(() => {
    console.error('⏱️  Forcing exit after 10s');
    process.exit(1);
  }, 10000).unref();

  process.exit(0);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// Tangkap unhandled rejection agar tidak crash diam-diam
process.on('unhandledRejection', (reason) => {
  console.error('❌ Unhandled Rejection:', reason);
});

process.on('uncaughtException', (err) => {
  console.error('❌ Uncaught Exception:', err);
  // Jangan langsung exit — biarkan graceful shutdown jika ada
  shutdown('uncaughtException');
});