const mongoose = require('mongoose');
const express = require('express');
const cors = require('cors');
const simulationService = require('./services/simulationService');
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
    timestamp: new Date()
  });
});

// MongoDB connection - SIMPLIFIED
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
    
    // Start simulation service
    simulationService.start();
  })
  .catch((err) => {
    console.error('❌ MongoDB connection error:', err.message);
    // Show partial connection string for debugging
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
    dbConnected: mongoose.connection.readyState === 1
  });
});

app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`🌐 API Base URL: http://localhost:${PORT}/api`);
  console.log(`📡 WebSocket URL: http://localhost:${PORT}`);
});