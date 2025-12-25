const mongoose = require('mongoose');
const { seedSampleData, clearSampleData } = require('./utils/seedData');
const User = require('./models/User');
const { hashPassword } = require('./utils/auth');
require('dotenv').config();

async function resetDatabase() {
  try {
    console.log('🔄 Resetting database...');
    
    // Connect to MongoDB Atlas - SIMPLIFIED
    await mongoose.connect(process.env.MONGODB_URI);
    
    console.log('✅ Connected to MongoDB Atlas');
    console.log(`📊 Database: ${mongoose.connection.db.databaseName}`);
    
    // Clear all existing data
    console.log('🗑️  Clearing existing data...');
    await clearSampleData();
    
    // Seed admin user
    console.log('👤 Creating admin user...');
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
      console.log('✅ Admin user created');
      console.log('👤 Username: admin');
      console.log('🔑 Password: admin123');
    } else {
      console.log('✅ Admin user already exists');
    }
    
    // Seed sample data
    console.log('🌱 Seeding sample data...');
    const result = await seedSampleData();
    
    console.log('🎉 Database reset completed!');
    console.log(result.message || '');
    
    // Count documents
    const Building = require('./models/Building');
    const Room = require('./models/Room');
    const IoTDevice = require('./models/IoTDevice');
    
    const buildingCount = await Building.countDocuments();
    const roomCount = await Room.countDocuments();
    const deviceCount = await IoTDevice.countDocuments();
    
    console.log('\n📊 Database Statistics:');
    console.log(`🏢 Buildings: ${buildingCount}`);
    console.log(`🚪 Rooms: ${roomCount}`);
    console.log(`📡 IoT Devices: ${deviceCount}`);
    
    // Show sample data
    console.log('\n🏢 Sample Buildings:');
    const buildings = await Building.find().limit(3);
    buildings.forEach(b => {
      console.log(`   - ${b.name} (${b.code || 'No code'})`);
    });
    
    console.log('\n🚪 Sample Rooms:');
    const rooms = await Room.find().populate('building', 'name').limit(3);
    rooms.forEach(r => {
      console.log(`   - ${r.name} in ${r.building?.name || r.buildingName}`);
    });
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error resetting database:', error.message);
    console.error('Stack:', error.stack);
    
    // Show connection string for debugging
    const uri = process.env.MONGODB_URI || '';
    const maskedUri = uri.replace(/:[^:@]*@/, ':****@');
    console.error('Connection string:', maskedUri);
    
    process.exit(1);
  }
}

resetDatabase();