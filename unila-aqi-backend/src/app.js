const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const simulationService = require('./services/simulationService');
const { seedSampleData } = require('./utils/seedData');
const seedRoutes = require('./routes/seedRoutes');
const testRoutes = require('./routes/testRoutes');
const buildingRoutes = require('./routes/buildingRoutes');
const roomRoutes = require('./routes/roomRoutes');
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

// Basic route for testing
app.get('/', (req, res) => {
  res.json({ message: 'UNILA AQI Backend API is running' });
});

// MongoDB connection
mongoose.connect(process.env.MONGODB_URI)
  .then(async () => {
    console.log('✅ Connected to MongoDB Atlas');
    
    // Seed admin user
    await seedInitialAdmin();
    
    // Seed sample buildings and rooms (only if empty)
    const Building = require('./models/Building');
    const buildingCount = await Building.countDocuments();
    if (buildingCount === 0) {
      await seedSampleData();
    } else {
      console.log('📊 Database already has data, skipping sample seeding');
    }
    
    // Start simulation service
    simulationService.start();
  })
  .catch((err) => console.error('❌ MongoDB connection error:', err));

// Start server
const PORT = process.env.PORT || 5000;
const seedInitialAdmin = async () => {
  try {
    const User = require('./models/User');
    const { hashPassword } = require('./utils/auth');
    
    // Cek apakah sudah ada admin
    const adminExists = await User.findOne({ role: 'admin' });
    
    if (!adminExists) {
      const hashedPassword = await hashPassword('admin123'); // password default
      const admin = new User({
        username: 'admin',
        password: hashedPassword,
        email: 'admin@unila-aqi.ac.id',
        role: 'admin'
      });
      
      await admin.save();
      console.log('✅ Initial admin user created');
      console.log('Username: admin');
      console.log('Password: admin123');
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
    status: 'OK'
  });
});

app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});