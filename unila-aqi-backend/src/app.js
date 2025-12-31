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

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*", // Allow all origins for development
    methods: ["GET", "POST", "PUT", "DELETE"],
    credentials: true
  }
});

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/seed', seedRoutes);
app.use('/api/test', testRoutes);
app.use('/api/buildings', buildingRoutes);
app.use('/api/rooms', roomRoutes);
app.use('/api/iot-devices', iotDeviceRoutes);
app.use('/api/sensor-data', sensorDataRoutes);

// Basic route for testing
app.get('/', (req, res) => {
  res.json({ 
    message: 'UNILA AQI Backend API is running',
    database: process.env.MONGODB_URI ? 'Connected' : 'Not configured',
    timestamp: new Date(),
    socketIO: 'Active'
  });
});

// Socket.io Connection Handler
io.on('connection', (socket) => {
  console.log(`🔌 New client connected: ${socket.id}`);
  
  // Join specific room
  socket.on('join-room', (roomId) => {
    socket.join(roomId);
    console.log(`📡 Socket ${socket.id} joined room: ${roomId}`);
  });
  
  // Leave room
  socket.on('leave-room', (roomId) => {
    socket.leave(roomId);
    console.log(`📡 Socket ${socket.id} left room: ${roomId}`);
  });
  
  // Handle disconnection
  socket.on('disconnect', () => {
    console.log(`🔌 Client disconnected: ${socket.id}`);
  });
  
  // Ping for connection testing
  socket.on('ping', () => {
    socket.emit('pong', { timestamp: new Date() });
  });
});

// Make io accessible to other modules
app.set('socketio', io);

// Function to broadcast room updates
const broadcastRoomUpdate = (roomId, data) => {
  if (io) {
    io.to(roomId).emit('room-update', {
      roomId,
      data,
      timestamp: new Date()
    });
    console.log(`📢 Broadcast update to room ${roomId}: AQI ${data.aqi}`);
  }
};

// Function to broadcast to all connected clients
const broadcastToAll = (event, data) => {
  if (io) {
    io.emit(event, data);
  }
};

// Export for use in other modules
module.exports = {
  broadcastRoomUpdate,
  broadcastToAll
};

// MongoDB connection
mongoose.connect(process.env.MONGODB_URI)
  .then(async () => {
    console.log('✅ Connected to MongoDB Atlas');
    console.log(`📊 Database: ${mongoose.connection.db.databaseName}`);
    console.log(`📍 Host: ${mongoose.connection.host}`);
    
    // Seed admin user
    await seedInitialAdmin();
    
    // Sync building names in rooms
    await syncBuildingNames();
    
    // Seed sample buildings and rooms
    const buildingCount = await Building.countDocuments();
    if (buildingCount === 0) {
      console.log('🌱 Seeding sample data...');
      await seedSampleData();
    } else {
      console.log(`📊 Database already has ${buildingCount} buildings, skipping sample seeding`);
    }
    
    // Start simulation service with socket.io instance
    simulationService.start(io);
    iotService.start(io);

    console.log('✅ All services started');
  })
  .catch((err) => {
    console.error('❌ MongoDB connection error:', err.message);
    const uri = process.env.MONGODB_URI || '';
    const maskedUri = uri.replace(/:[^:@]*@/, ':****@');
    console.error('Connection string:', maskedUri);
  });

// Function to sync building names
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

// Start server
const PORT = process.env.PORT || 5000;

const seedInitialAdmin = async () => {
  try {
    const User = require('./models/User');
    const { hashPassword } = require('./utils/auth');
    
    // Cek apakah sudah ada admin
    const adminExists = await User.findOne({ role: 'admin' });
    
    if (!adminExists) {
      const hashedPassword = await hashPassword('admin123');
      const admin = new User({
        username: 'admin',
        password: hashedPassword,
        email: 'admin@unila-aqi.ac.id',
        role: 'admin'
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

app.get('/api/simple-test', (req, res) => {
  res.json({
    message: 'Simple test endpoint working',
    timestamp: new Date(),
    status: 'OK',
    dbConnected: mongoose.connection.readyState === 1,
    socketConnected: io !== undefined
  });
});


app.post('/api/force-refresh', async (req, res) => {
  try {
    // Force simulation service to update
    simulationService.updateAllRooms();
    
    // Force IoT service to poll
    iotService.forcePollAll();
    
    res.json({
      success: true,
      message: 'Force refresh initiated',
      timestamp: new Date()
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error forcing refresh',
      error: error.message
    });
  }
});

server.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`🌐 API Base URL: http://localhost:${PORT}/api`);
  console.log(`📡 WebSocket URL: ws://localhost:${PORT}`);
  console.log(`🔌 Socket.IO ready for real-time updates`);
});